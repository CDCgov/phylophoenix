/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPhylophoenix.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Modules for running all vs all
//

include { XLSX_TO_TSV                  } from '../modules/local/excel_to_tsv'
include { GRIPHIN_WORKFLOW             } from '../subworkflows/local/griphin_workflow'
include { GET_COMPARISONS              } from '../modules/local/create_comparisons'
include { MASH_DIST    as MASH_DIST    } from '../modules/local/mash_distance'
include { GET_CENTROID as GET_CENTROID } from '../modules/local/get_centroid'
include { ASSET_PREP   as ASSET_PREP   } from '../modules/local/asset_prep'
include { CREATE_META  as CREATE_META  } from '../subworkflows/local/create_meta'
include { SNVPHYL                      } from '../subworkflows/local/snvphyl'
include { RENAME_REF_IN_OUTPUT         } from '../modules/local/rename_ref_in_output'
include { CLEAN_AND_CREATE_METADATA    } from '../modules/local/clean_and_create_metadata'
include { COMBINE_GRIPHIN_SNVPHYL      } from '../modules/local/combine_griphin_snvphyl'

//
// Modules for running snvphyl by st
//

include { GET_SEQUENCE_TYPES                                           } from '../modules/local/get_sequence_types'
include { CREATE_META               as CREATE_META_BY_ST               } from '../subworkflows/local/create_meta'
include { MASH_DIST                 as MASH_DIST_BY_ST                 } from '../modules/local/mash_distance'
include { GET_CENTROID              as GET_CENTROID_BY_ST              } from '../modules/local/get_centroid'
include { ASSET_PREP                as ASSET_PREP_BY_ST                } from '../modules/local/asset_prep'
include { SNVPHYL                   as SNVPHYL_BY_ST                   } from '../subworkflows/local/snvphyl'
include { RENAME_REF_IN_OUTPUT      as RENAME_REF_IN_OUTPUT_BY_ST      } from '../modules/local/rename_ref_in_output'
include { CLEAN_AND_CREATE_METADATA as CLEAN_AND_CREATE_METADATA_BY_ST } from '../modules/local/clean_and_create_metadata'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CREATE_INPUT_CHANNELS       } from '../subworkflows/local/create_input_channels'

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
========================================================================================
    GROOVY FUNCTIONS
========================================================================================
*/

def add_empty_ch(input_ch) {
    def meta_seq_type = input_ch[0]
    output_array = [ meta_seq_type, []]
    return output_array
}

def get_taxa_and_project_ID(input_ch){ 
    def genus = ""
    def species = ""
    input_ch[1].eachLine { line ->
        if (line.startsWith("G:")) {
            def parts = line.split(":")[1].trim().split('\t')
            genus = parts.size() > 1 ? parts[1] : parts[0]
        } else if (line.startsWith("s:")) {
            def parts = line.split(":")[1].trim().split('\t')
            species = parts.size() > 1 ? parts[1] : parts[0]
        }
    }
    //def clean_project_id = in_meta.project_id.replaceAll(/^['"]/, '').replaceAll(/['"]$/, '')
    return [input_ch[0], "$genus", input_ch[2] ]
}

    /*     //input_samplesheet_path - channel: path('*.tsv','*.xlsx'): User input samplesheet
        normalized_samplesheet_ch = input_samplesheet_path.first().map { file ->
                if( file.name.toLowerCase().endsWith('.xlsx') ) { return [ 'xlsx', file ] }
                else if( file.name.toLowerCase().endsWith('.tsv') ) { return [ 'tsv', file ] } 
                else { error "Unsupported samplesheet type: ${file.name}" } }

        normalized_samplesheet_ch.view()

        // Branch based on file type
        normalized_tsv_ch = normalized_samplesheet_ch.branch( xlsx:{ it[0] == 'xlsx' }, tsv:{ it[0] == 'tsv' } )

        // Convert XLSX → TSV if needed (only runs if xlsx branch has data)
        XLSX_TO_TSV (
            normalized_tsv_ch.xlsx.map{ it[1] }
        )
        ch_versions = ch_versions.mix(XLSX_TO_TSV.out.versions)
        
        // Pass TSV through unchanged and merge with converted XLSX
        final_tsv_ch = XLSX_TO_TSV.out.tsv_samplesheet.ifEmpty{ Channel.empty() }.mix(normalized_tsv_ch.tsv.map{ it[1] })
        
        */

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
//def multiqc_report = []

workflow PHYLOPHOENIX {
    take:
        input_samplesheet_path
        by_st
        ch_versions

    main:
        // get geonames file into a channel. Coding it this way and not params so we can use a glob and not be verbose.
        geonames_ch = Channel.fromPath("${baseDir}/assets/databases/*_geolocation.txt.xz").collect()
        // Allow outdir to be relative
        outdir_path = Channel.fromPath(params.outdir, relative: true)

        // Create input channels for files we need to make griphin
        CREATE_INPUT_CHANNELS (
            // False is to say if centar is to be included when creating input channels
            input_samplesheet_path,  false
        )
        ch_versions = ch_versions.mix(CREATE_INPUT_CHANNELS.out.versions)

        //metadata check for correct columns in metadata file if provided - do they match they sample names in the samplesheet?

        // Compute BUSCO boolean
        project_files_ch = CREATE_INPUT_CHANNELS.out.griphin_tsv_ch.map{ meta, summary_line -> summary_line.readLines().first().contains('BUSCO')}.collect().unique()

        has_busco_ch = project_files_ch.map{ it -> 
            if (it.size() > 1) {
                // More than one element -> mixed CDC/PHX, default to PHX (false)
                System.err.println("WARNING: Mix of CDC_PHOENIX and PHOENIX in GRiPHins — defaulting to PHX.")
                return false
            } else if (it.size() == 1) {
                // Single element: return that boolean value
                return it[0]
            }
        }

        // Determine if ShigaPass was run and if Shigella/Escherichia detected
        shigapass_var_ch =  CREATE_INPUT_CHANNELS.out.griphin_tsv_ch.map{ meta, summary_line -> summary_line.readLines().first().contains('ShigaPass_Organism')}.collect().unique()
        phx_version_ch =  CREATE_INPUT_CHANNELS.out.pipeline_info.map{ meta, pipeline_versions -> 
            def line = pipeline_versions.readLines().find { it.contains('cdcgov/phoenix:') } 
            line ? line.split(':')[1].trim() : null }

        //create GRiPHin report channel
        griphin_inputs_ch = Channel.empty()
            .mix(
                CREATE_INPUT_CHANNELS.out.fastp_total_qc,
                CREATE_INPUT_CHANNELS.out.raw_stats,
                CREATE_INPUT_CHANNELS.out.k2_trimd_bh_summary,
                CREATE_INPUT_CHANNELS.out.k2_trimd_report,
                CREATE_INPUT_CHANNELS.out.k2_wtasmbld_bh_summary,
                CREATE_INPUT_CHANNELS.out.k2_wtasmbld_report,
                CREATE_INPUT_CHANNELS.out.quast_report,
                CREATE_INPUT_CHANNELS.out.fairy_outcome,
                CREATE_INPUT_CHANNELS.out.combined_mlst,
                CREATE_INPUT_CHANNELS.out.taxonomy,
                CREATE_INPUT_CHANNELS.out.assembly_ratio,
                CREATE_INPUT_CHANNELS.out.gc_content,
                CREATE_INPUT_CHANNELS.out.gamma_ar,
                CREATE_INPUT_CHANNELS.out.gamma_pf,
                CREATE_INPUT_CHANNELS.out.gamma_hv,
                CREATE_INPUT_CHANNELS.out.ani_best_hit,
                CREATE_INPUT_CHANNELS.out.synopsis,
                CREATE_INPUT_CHANNELS.out.shigapass,
                CREATE_INPUT_CHANNELS.out.busco_short_summary,
                CREATE_INPUT_CHANNELS.out.srst2_ar,
            )
            .groupTuple()
            .map { meta, files ->
                def cleaned = files.findAll { f ->
                    def ok = f != null && (f instanceof java.nio.file.Path || f instanceof nextflow.file.FileHolder)
                    if (!ok) println "WARNING [${meta.id}]: dropping invalid file entry: ${f}"
                    ok
                }

                [
                    meta: [ id: "${meta.id}", filenames: cleaned.collect { it.getName() } ],
                    files: cleaned
                ]
            }

        // Create report
        GRIPHIN_WORKFLOW (
            input_samplesheet_path,
            params.blind_list,
            workflow.manifest.version,
            params.ardb,
            params.prefix,
            params.coverage,
            params.force,
            params.bldb,
            has_busco_ch,
            shigapass_var_ch,
            griphin_inputs_ch,
            phx_version_ch,
            outdir_path
        )
        ch_versions = ch_versions.mix(GRIPHIN_WORKFLOW.out.versions)

        // If you pass --no_all then samples will not be run all together
        if (params.no_all==false) {
            // Allow outdir to be relative
            //outdir_path = Channel.fromPath(params.outdir, relative: true, type: 'dir')
            // Creates samplesheets with sampleid,seq_type,path_to_assembly
            GET_COMPARISONS (
                GRIPHIN_WORKFLOW.out.directory_samplesheet, GRIPHIN_WORKFLOW.out.griphin_tsv_report, params.combine_complex
            )
            ch_versions = ch_versions.mix(GET_COMPARISONS.out.versions)

            if (params.metadata!=null) {
                // get metadata into channel
                metadata  = Channel.fromPath(params.metadata, relative: true)
                // creates channel: [ val(meta.id, meta.st), [ scaffolds_1, scaffolds_2 ] ]
                CREATE_META (
                    GET_COMPARISONS.out.samplesheet, GET_COMPARISONS.out.snv_samplesheet, metadata, false, CREATE_INPUT_CHANNELS.out.reads
                )
                ch_versions = ch_versions.mix(CREATE_META.out.versions)
            } else {
                // creates channel: [ val(meta.id, meta.st), [ scaffolds_1, scaffolds_2 ] ]
                CREATE_META (
                    GET_COMPARISONS.out.samplesheet, GET_COMPARISONS.out.snv_samplesheet, null, false, CREATE_INPUT_CHANNELS.out.reads
                )
                ch_versions = ch_versions.mix(CREATE_META.out.versions)
            }

            // Run Mash on groups of samples by seq type
            MASH_DIST (
                CREATE_META.out.st_scaffolds
            )
            ch_versions = ch_versions.mix(MASH_DIST.out.versions)

            // Creating channel [ ST, [distance_1, distance_2] ]
            dist_ch = MASH_DIST.out.dist.map { meta, file -> [meta.seq_type, meta, file] } // Add seq_type as key
                .groupTuple() // Group by seq_typ
                .map { seq_type, old_meta, files -> 
                        def meta = [:]
                        meta.seq_type = old_meta.seq_type.unique()[0]
                        //meta.taxa = old_meta.taxa.unique()[0]
                        return tuple ( meta, files ) } // Restructure to orginal format
            centroid_ch = dist_ch.combine(GRIPHIN_WORKFLOW.out.directory_samplesheet)

            // Take in all mash distance files then use the samplesheet to return the centroid assembly
            // Get centroid, by calculating the average mash distance
            GET_CENTROID (
                centroid_ch
            )
            ch_versions = ch_versions.mix(GET_CENTROID.out.versions)

            // Unzip centroid assembly: SNVPhyl requires it unzipped
            // also unzip the geoname files for cleaning metadata file. 
            ASSET_PREP (
                // Bring in centroid into channel
                GET_CENTROID.out.centroid_path.splitCsv( header:false, sep:',' ).map{meta, list -> 
                def scaffold = list[0] // extract the file from the list
                return [meta, scaffold]},  // get into format [[meta], scaffold]
                geonames_ch, CREATE_META.out.st_snv_samplesheets
            )
            ch_versions = ch_versions.mix(ASSET_PREP.out.versions)

            // Check and correct the metadata file if it was passed
            if (params.metadata!=null) {
                //get files in the same tuple for cleaner coding
                assets_ch = ASSET_PREP.out.unzipped_geodata.map{africa, americas, eu, other, sea, us -> [[africa, americas, eu, other, sea, us]]}
                //combine files in channels so they aren't comsumed.
                //we need to have .first() as there might be more coming out of that channel than needed - i.e. not all STs continue since there is a min number of isolates required to continue.
                metadata_ch = CREATE_META.out.split_metadata.combine(GRIPHIN_WORKFLOW.out.griphin_tsv_report).combine(assets_ch.first())
                // clean up metadata file, add geolocation information
                CLEAN_AND_CREATE_METADATA (
                    metadata_ch.map{meta, metadata, griphin, assets -> [meta, metadata]},
                    metadata_ch.map{meta, metadata, griphin, assets -> [griphin]},
                    metadata_ch.map{meta, metadata, griphin, assets -> assets},
                    params.bldb
                )
                ch_versions = ch_versions.mix(CLEAN_AND_CREATE_METADATA.out.versions)
            }

            // Get the centroid id for each sample to filter out from the SNVPhyl run. 
            // This is done by taking the centroid file, looking for the line that says "is set as the centroid" and extracting the sample name from that line.
            //GET_CENTROID.out.centroid_info.map{ meta, centroid_file -> log.info "parsed centroid_id: ${(centroid_file.text =~ /(\S+) is set as the centroid/)[0][1]}"}

            centroid_id_ch = GET_CENTROID.out.centroid_info.map{ meta, centroid_file ->
                                def centroid_id = (centroid_file.text =~ /(\S+) is set as the centroid/)[0][1]
                                tuple(meta.seq_type, centroid_id)
                            }

            filtered_reads_ch = CREATE_META.out.st_reads.map{ meta, fastqs -> tuple(meta.seq_type, meta.id, fastqs) }
                .combine(centroid_id_ch, by: 0)
                .filter{ seq_type, sample_id, fastqs, centroid_id -> sample_id != centroid_id }
                .map{ seq_type, sample_id, fastqs, centroid_id -> tuple([seq_type: seq_type, id: sample_id], fastqs)}

            /*all_ch = CREATE_META.out.st_reads.map{ meta, fastqs -> tuple(meta.seq_type, fastqs, meta.id) }
                .combine(GET_CENTROID.out.centroid_info.map { meta, unzipped_fasta -> tuple(meta.seq_type, unzipped_fasta) }, by: 0)
                .map{ seq_type, fastqs, id, unzipped_fasta -> tuple([seq_type: seq_type, id: id], fastqs, unzipped_fasta)}*/

            // Run snvphyl on each st type on its own input
            SNVPHYL (
                filtered_reads_ch,
                ASSET_PREP.out.unzipped_fasta,
                params.window_size
            )
            ch_versions = ch_versions.mix(SNVPHYL.out.versions)

            if (params.metadata!=null) {
                final_output_ch = GET_CENTROID.out.centroid_info.join(SNVPHYL.out.phylogeneticTree, by: [0], remainder: true).join(SNVPHYL.out.snvMatrix, by: [0]).join(CLEAN_AND_CREATE_METADATA.out.updated_metadata, by: [0])
                                    .map { meta, centroid, phylo, matrix, empty -> tuple(meta, centroid, phylo ?: [], matrix, empty) }
            } else {
                // create empty channel as for CLEAN_AND_CREATE_METADATA that wasn't run and is required for the RENAME_REF_IN_OUTPUT module
                empty_ch = SNVPHYL.out.snvMatrix.map{ it -> add_empty_ch(it) }
                //.map{ items -> items.size() > 1 ? items.flatten() : items}
                final_output_ch = GET_CENTROID.out.centroid_info.join(SNVPHYL.out.phylogeneticTree, by: [0], remainder: true).join(SNVPHYL.out.snvMatrix, by: [0]).join(empty_ch, by: [0])
                                    .map { meta, centroid, phylo, matrix, empty -> tuple(meta, centroid, phylo ?: [], matrix, empty) }
            }

            // Rename reference to actual sample name
            RENAME_REF_IN_OUTPUT (
                final_output_ch
            )
            ch_versions = ch_versions.mix(RENAME_REF_IN_OUTPUT.out.versions)

        }

        // If you pass --by_st then samples will be broken up by st type and SNVPhyl run on each st on its own
        if (by_st==true) {

            // Creates samplesheets with sample,seq_type,path_to_assembly
            if (params.blind_list != null){ // if control list is passed allow it to be relative
                // Allow control list to be relative
                blind_path = Channel.fromPath(params.blind_list, relative: true)
                // get sequence types with a blind list
                GET_SEQUENCE_TYPES (
                    GRIPHIN_WORKFLOW.out.directory_samplesheet, GRIPHIN_WORKFLOW.out.griphin_report, blind_path, params.use_secondary_mlst, params.combine_complex
                )
                ch_versions = ch_versions.mix(GET_SEQUENCE_TYPES.out.versions)
            } else {
                // get sequence types without a blind list
                GET_SEQUENCE_TYPES (
                    GRIPHIN_WORKFLOW.out.directory_samplesheet, GRIPHIN_WORKFLOW.out.griphin_report, [], params.use_secondary_mlst, params.combine_complex
                )
                ch_versions = ch_versions.mix(GET_SEQUENCE_TYPES.out.versions)
            }

            if (params.metadata!=null) {
                // get metadata into channel
                metadata  = Channel.fromPath(params.metadata, relative: true)

                // creates channel: [ val(meta.id, meta.st), [ scaffolds_1, scaffolds_2 ] ]
                CREATE_META_BY_ST (
                    GET_SEQUENCE_TYPES.out.st_samplesheets, GET_SEQUENCE_TYPES.out.st_snv_samplesheets, metadata, true, CREATE_INPUT_CHANNELS.out.reads
                )
            } else {
                // creates channel: [ val(meta.id, meta.st), [ scaffolds_1, scaffolds_2 ] ]
                CREATE_META_BY_ST (
                    GET_SEQUENCE_TYPES.out.st_samplesheets, GET_SEQUENCE_TYPES.out.st_snv_samplesheets, null, false, CREATE_INPUT_CHANNELS.out.reads
                )
            }

            // Run Mash on groups of samples by seq type
            MASH_DIST_BY_ST (
                CREATE_META_BY_ST.out.st_scaffolds
            )
            ch_versions = ch_versions.mix(MASH_DIST_BY_ST.out.versions)

            // Creating channel [ ST, [distance_1, distance_2] ]
            st_mash_dists = MASH_DIST_BY_ST.out.dist.map{ meta, mash_dist -> 
                    def key = meta.seq_type 
                    return tuple (key, mash_dist)}
                .groupTuple() //group by st type. this returns [ST#, [ distance_1, distance_2 ]]
                .map{meta_old, mash_dists -> 
                    def meta = [:]
                    meta.seq_type = meta_old
                    return tuple( meta, mash_dists)} // Now returns [[meta.seq_type], [ distance_1, distance_2 ]]

            // Add samplesheet to all mash distance channels
            centroid_st_ch =  st_mash_dists.combine(GRIPHIN_WORKFLOW.out.directory_samplesheet)

            // Take in all mash distance files for a seq type and then use the samplesheet to return the centroid assembly
            // Get centroid for ST groups, by calculating the average mash distance
            GET_CENTROID_BY_ST (
                centroid_st_ch
            )
            ch_versions = ch_versions.mix(GET_CENTROID_BY_ST.out.versions)

            // make sure that seq_type is the same for the centroid path and st_snv sheet. 
            asset_prep_ch = GET_CENTROID_BY_ST.out.centroid_path.join(CREATE_META_BY_ST.out.st_snv_samplesheets, by:[0])

            // Unzip centroid assembly: SNVPhyl requires it unzipped
            ASSET_PREP_BY_ST (
                asset_prep_ch.map{meta, centroid_path, st_snv_samplesheets -> [meta, centroid_path]}.splitCsv( header:false, sep:',' ), // Bring in centroid into channel
                geonames_ch,
                asset_prep_ch.map{meta, centroid_path, st_snv_samplesheets -> [meta, st_snv_samplesheets]}
            )
            ch_versions = ch_versions.mix(ASSET_PREP_BY_ST.out.versions)

            // Check and correct the metadata file
            if (params.metadata!=null) {
                //get files in the same tuple for cleaner coding
                assets_ch = ASSET_PREP_BY_ST.out.unzipped_geodata.map{africa, americas, eu, other, sea, us -> [[africa, americas, eu, other, sea, us]]}
                //combine files in channels so they aren't comsumed.
                //we need to have .first() as there might be more coming out of that channel than needed - i.e. not all STs continue since there is a min number of isolates required to continue.
                metadata_ch = CREATE_META_BY_ST.out.split_metadata.combine(GRIPHIN_WORKFLOW.out.griphin_tsv_report).combine(assets_ch.first())
                // clean up metadata file, add geolocation information
                CLEAN_AND_CREATE_METADATA_BY_ST (
                    metadata_ch.map{meta, metadata, griphin, assets -> [meta, metadata]},
                    metadata_ch.map{meta, metadata, griphin, assets -> [griphin]},
                    metadata_ch.map{meta, metadata, griphin, assets -> assets},
                    params.bldb
                )
                ch_versions = ch_versions.mix(CLEAN_AND_CREATE_METADATA_BY_ST.out.versions)
            }

            /*st_ch = CREATE_META_BY_ST.out.st_reads.map{meta, fastqs -> tuple(meta.seq_type, fastqs, meta.id)}
                .combine(ASSET_PREP_BY_ST.out.unzipped_fasta.map{meta, unzipped_fasta -> tuple(meta.seq_type, unzipped_fasta)}, by: 0)
                .map{seq_type, fastqs, id, unzipped_fasta -> tuple([seq_type: seq_type, id: id], fastqs, unzipped_fasta)}*/

            // Get the centroid id for each sample to filter out from the SNVPhyl run. 
            // This is done by taking the centroid file, looking for the line that says "is set as the centroid" and extracting the sample name from that line.

            centroid_id_by_st_ch = GET_CENTROID_BY_ST.out.centroid_info.map{ meta, centroid_file ->
                                def centroid_id = (centroid_file.text =~ /(\S+) is set as the centroid/)[0][1]
                                tuple(meta.seq_type, centroid_id)
                            }

            centroid_id_by_st_ch.view()

            filtered_reads_by_st_ch = CREATE_META_BY_ST.out.st_reads.map{ meta, fastqs -> tuple(meta.seq_type, meta.id, fastqs) }
                .combine(centroid_id_by_st_ch, by: 0)
                .filter{ seq_type, sample_id, fastqs, centroid_id -> sample_id != centroid_id }
                .map{ seq_type, sample_id, fastqs, centroid_id -> tuple([seq_type: seq_type, id: sample_id], fastqs)}

            // Run snvphyl on each st type on its own input
            SNVPHYL_BY_ST (
                filtered_reads_by_st_ch,
                ASSET_PREP_BY_ST.out.unzipped_fasta, // reference
                params.window_size
            )
            ch_versions = ch_versions.mix(SNVPHYL_BY_ST.out.versions)

            if (params.metadata!=null) {
                final_output_by_st_ch = GET_CENTROID_BY_ST.out.centroid_info.join(SNVPHYL_BY_ST.out.phylogeneticTree, by: [0], remainder: true).join(SNVPHYL_BY_ST.out.snvMatrix, by: [0]).join(CLEAN_AND_CREATE_METADATA_BY_ST.out.updated_metadata, by: [0])
                                            .map { meta, centroid, phylo, matrix, empty -> tuple(meta, centroid, phylo ?: [], matrix, empty) }
            } else {
                // create empty channel as for CLEAN_AND_CREATE_METADATA that wasn't run and is required for the RENAME_REF_IN_OUTPUT module
                empty_ch = SNVPHYL_BY_ST.out.snvMatrix.map{ it -> add_empty_ch(it) }
                final_output_by_st_ch = GET_CENTROID_BY_ST.out.centroid_info.join(SNVPHYL_BY_ST.out.phylogeneticTree, by: [0], remainder: true).join(SNVPHYL_BY_ST.out.snvMatrix, by: [0]).join(empty_ch, by: [0])
                                            .map { meta, centroid, phylo, matrix, empty -> tuple(meta, centroid, phylo ?: [], matrix, empty) }
            }

            // Rename reference to actual sample name
            RENAME_REF_IN_OUTPUT_BY_ST (
                final_output_by_st_ch
            )
            ch_versions = ch_versions.mix(RENAME_REF_IN_OUTPUT_BY_ST.out.versions)
        }

        if (by_st==true) {
            if (params.no_all==false) {
                // collect files to add to griphin summary
                snvMatrix_ch = RENAME_REF_IN_OUTPUT.out.snvMatrix.collect().combine(RENAME_REF_IN_OUTPUT_BY_ST.out.snvMatrix.collect())
                vcf2core_ch = SNVPHYL.out.vcf2core.map{ meta, vcf2core -> vcf2core }.collect().combine(SNVPHYL_BY_ST.out.vcf2core.map{ meta, vcf2core -> vcf2core }.collect())
            } else {
                // collect files to add to griphin summary
                snvMatrix_ch = RENAME_REF_IN_OUTPUT_BY_ST.out.snvMatrix.collect()
                vcf2core_ch = SNVPHYL_BY_ST.out.vcf2core.map{ meta, vcf2core -> vcf2core }.collect()
            }
        } else {
            // collect files to add to griphin summary
            snvMatrix_ch = RENAME_REF_IN_OUTPUT.out.snvMatrix.collect()
            vcf2core_ch = SNVPHYL.out.vcf2core.map{ meta, vcf2core -> vcf2core }.collect()
        }

        if (params.blind_list != null){ // if control list is passed allow it to be relative
            // Allow control list to be relative
            blind_path = Channel.fromPath(params.blind_list, relative: true)
            // Create report
            COMBINE_GRIPHIN_SNVPHYL (
                snvMatrix_ch, vcf2core_ch, GRIPHIN_WORKFLOW.out.griphin_report, blind_path, params.window_size, params.combine_complex
            )
            ch_versions = ch_versions.mix(COMBINE_GRIPHIN_SNVPHYL.out.versions)

        } else {
            // combine without blinding
            COMBINE_GRIPHIN_SNVPHYL (
                snvMatrix_ch, vcf2core_ch, GRIPHIN_WORKFLOW.out.griphin_report, [], params.window_size, params.combine_complex
            )
            ch_versions = ch_versions.mix(COMBINE_GRIPHIN_SNVPHYL.out.versions)
        }


        CUSTOM_DUMPSOFTWAREVERSIONS (
            ch_versions.unique().collectFile(name: 'collated_versions.yml')
        )

    emit:
        griphin_report = GRIPHIN_WORKFLOW.out.griphin_report

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
