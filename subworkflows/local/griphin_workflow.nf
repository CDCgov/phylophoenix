//
// Subworkflow: one of the workflows to generate a report
//

include { GRIPHIN            } from '../../modules/local/griphin'
include { CREATE_SAMPLESHEET } from '../../modules/local/create_samplesheet'
include { REMOVE_FAILURES    } from '../../modules/local/remove_failures'

workflow GRIPHIN_WORKFLOW {
    take:
        input_samplesheet_path // channel: tuple val(meta), path('*.json'): FASTP_TRIMD.out.json --> PHOENIX_EXQC.out.paired_trmd_json
        indir                  // channel: path to one PHoeNIx output directory containing all samples to be analyzed
        blind_list             // path: path to a blind list file (optional)
        version                // manifest version of the workflow
        ardb                   // path: path to ARDB database for GRiPHin
        prefix                 // string: prefix for output files and directories
        coverage               // integer: minimum coverage value for GRIPHin
        force                  // boolean: if true will not remove samples that fail PHX specs
        bldb                   // path: path to BLDB database for GRiPHin
        busco_bool             // boolean: indicates if busco was run in the PHoeNIx workflow
        shigapass_bool         // channel: indicates if shigapass is detected in the input samples
        griphin_inputs         // channel: all input files for GRiPHin
        orginal_phx_version    // string: original PHoenix version used to generate the input files
        outdir


    main:
        ch_versions = Channel.empty() // Used to collect the software versions

        // Check if input samplesheet or input directory has passed, then check if a control list was passed
        // we have to do all this to make sure paths can be relative
        if (input_samplesheet_path != null) { // if samplesheet is passed
            if (blind_list != null){ // if control list is passed allow it to be relative

                // Allow control list to be relative
                blind_path = Channel.fromPath(blind_list, relative: true)

                //create GRiPHin report
                GRIPHIN (
                    ardb,                                         // path(db)
                    input_samplesheet_path,                       // path(original_samplesheet)
                    griphin_inputs.map{ it.meta }.collect(),     // val(metas): list of [id:<sid>, filenames:[...]]
                    griphin_inputs.map{ it.files }.collect(),    // path(griphin_files): flattened file list
                    outdir,                                       // path(outdir): full_project_id
                    version,                                      // val(phx_version)
                    coverage,                                     // val(coverage)
                    busco_bool,                                   // val(entry): busco_boolean
                    shigapass_bool,                               // val(shigapass_detected)
                    false,                                        // val(centar_detected)
                    bldb,                                         // path(bldb)
                    false,                                        // val(filter_var)
                    true,                                         // val(dont_publish) --> need it for the naming of the output files
                    blind_path,                                   // path(blind_list)
                    orginal_phx_version                           // val(old_phx_version)
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)

            } else {

                //create GRiPHin report
                GRIPHIN (
                    ardb,                                         // path(db)
                    input_samplesheet_path,                       // path(original_samplesheet)
                    griphin_inputs.map{ it.meta }.collect(),  // val(metas): list of [id:<sid>, filenames:[...]]
                    griphin_inputs.map{ it.files }.collect(), // path(griphin_files): flattened file list
                    outdir,                                       // path(outdir): full_project_id
                    version,                                      // val(phx_version)
                    coverage,                                     // val(coverage)
                    busco_bool,                                   // val(entry): busco_boolean
                    shigapass_bool,                               // val(shigapass_detected)
                    false,                                        // val(centar_detected)
                    bldb,                                         // path(bldb)
                    false,                                        // val(filter_var)
                    true,                                         // val(dont_publish) --> need it for the naming of the output files
                    [],                                           // path(blind_list)
                    orginal_phx_version                           // val(old_phx_version)
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            }
            directory_samplesheet = GRIPHIN.out.converted_samplesheet
        } else { // if no samplesheet is passed the we will make one

            // Create samplesheet - while GRiPHin can create a samplesheet for you, due to nextflow/softlinks etc this results in failures at the create_meta step.
            // so we are just using another process to create the samplesheet :)
            // sample_id,/path/sample_folder
            CREATE_SAMPLESHEET (
                indir
            )
            ch_versions = ch_versions.mix(CREATE_SAMPLESHEET.out.versions)

            if (blind_list != null){ // if control list is passed allow it to be relative
                // Allow control list to be relative
                blind_path = Channel.fromPath(blind_list, relative: true)

                //create GRiPHin report
                GRIPHIN (
                    ardb,                                         // path(db)
                    CREATE_SAMPLESHEET.out.samplesheet,          // path(original_samplesheet)
                    griphin_inputs.map{ it.meta }.collect(),  // val(metas): list of [id:<sid>, filenames:[...]]
                    griphin_inputs.map{ it.files }.collect(), // path(griphin_files): flattened file list
                    outdir,                                       // path(outdir): full_project_id
                    version,                                      // val(phx_version)
                    coverage,                                     // val(coverage)
                    busco_bool,                                   // val(entry): busco_boolean
                    shigapass_bool,                               // val(shigapass_detected)
                    false,                                        // val(centar_detected)
                    bldb,                                         // path(bldb)
                    false,                                        // val(filter_var)
                    true,                                         // val(dont_publish) --> need it for the naming of the output files
                    blind_path,                                   // path(blind_list)
                    orginal_phx_version                           // val(old_phx_version)
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)

                /*GRIPHIN (
                    ardb, CREATE_SAMPLESHEET.out.samplesheet, prefix, blind_path, version, coverage, bldb, busco_bool
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)*/
            } else {

                //create GRiPHin report
                GRIPHIN (
                    ardb,                                         // path(db)
                    CREATE_SAMPLESHEET.out.samplesheet,            // path(original_samplesheet)
                    griphin_inputs.map{ it.meta }.collect(),  // val(metas): list of [id:<sid>, filenames:[...]]
                    griphin_inputs.map{ it.files }.collect(), // path(griphin_files): flattened file list
                    outdir,                                       // path(outdir): full_project_id
                    version,                                      // val(phx_version)
                    coverage,                                     // val(coverage)
                    busco_bool,                                   // val(entry): busco_boolean
                    shigapass_bool,                               // val(shigapass_detected)
                    false,                                        // val(centar_detected)
                    bldb,                                         // path(bldb)
                    false,                                        // val(filter_var)
                    true,                                         // val(dont_publish) --> need it for the naming of the output files
                    [],                                           // path(blind_list)
                    orginal_phx_version                           // val(old_phx_version)
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)

                /*GRIPHIN (
                    ardb, CREATE_SAMPLESHEET.out.samplesheet,  prefix, blind_path, version, coverage, bldb, busco_bool
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)*/
            }
            directory_samplesheet = CREATE_SAMPLESHEET.out.samplesheet
        }

        // Identify samples failed PHX specs
        REMOVE_FAILURES(
            GRIPHIN.out.griphin_tsv_report, directory_samplesheet
        )
        ch_versions = ch_versions.mix(REMOVE_FAILURES.out.versions)

        if (force==false) {
            final_directory_samplesheet = REMOVE_FAILURES.out.cleaned_dir_samplesheet
        } else {
            final_directory_samplesheet = directory_samplesheet
        }

        //ids_to_remove_ch = REMOVE_FAILURES.out.failured_ids.splitCsv( header:false, sep:',' )
        // add in the reads to the channel
        //filtered_reads = reads.map{reads -> [ reads ] }.combine(ids_to_remove_ch).map{reads, ids_to_remove_ch -> filter_reads(reads, ids_to_remove_ch) }.flatten()

    emit:
        griphin_report        = GRIPHIN.out.griphin_excel_report      // channel: [ val(meta), path('SNVPhyl_Griphin_Summary.xlsx') ]
        griphin_tsv_report    = GRIPHIN.out.griphin_tsv_report  // channel: [ val(meta), path('SNVPhyl_Griphin_Summary.tsv') ]
        directory_samplesheet = final_directory_samplesheet     // channel: [ val(meta), path('Directory_samplesheet.csv') ]
        versions              = ch_versions                     // channel: [ versions.yml ]
}