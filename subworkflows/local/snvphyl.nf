//
// Subworkflow: Running SNVPhyl from --> https://github.com/DHQP/SNVPhyl_Nextflow/tree/nf-core
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CONVERT_INPUT                } from '../../modules/local/convert_input'
include { INDEXING                     } from '../../modules/local/snvphyl/indexing'
include { FIND_REPEATS                 } from '../../modules/local/snvphyl/find_repeats'
include { SMALT_MAP                    } from '../../modules/local/snvphyl/smalt_map'
include { SORT_INDEX_BAMS              } from '../../modules/local/snvphyl/sort_index_bams'
include { GENERATE_LINE_1              } from '../../modules/local/snvphyl/generate_line_1'
include { VERIFYING_MAP_Q              } from '../../modules/local/snvphyl/verifying_map_q'
include { FREEBAYES                    } from '../../modules/local/snvphyl/freebayes'
include { FILTER_FREEBAYES             } from '../../modules/local/snvphyl/filter_freebayes'
include { BGZIP_FREEBAYES_VCF          } from '../../modules/local/snvphyl/bgzip_freebayes_vcf'
include { FREEBAYES_VCF_TO_BCF         } from '../../modules/local/snvphyl/freebayes_vcf_to_bcf'
include { MPILEUP                      } from '../../modules/local/snvphyl/mpileup'
include { BGZIP_MPILEUP_VCF            } from '../../modules/local/snvphyl/bgzip_mpileup_vcf'
include { BCFTOOLS_CALL                } from '../../modules/local/snvphyl/bcftools_call'
include { CONSOLIDATE_BCFS             } from '../../modules/local/snvphyl/consolidate_bcfs'
include { CONSOLIDATE_FILTERED_DENSITY } from '../../modules/local/snvphyl/consolidate_filtered_density'
include { GENERATE_LINE_2              } from '../../modules/local/snvphyl/generate_line_2'
include { FILTER_STATS                 } from '../../modules/local/snvphyl/filter_stats'
include { VCF2SNV_ALIGNMENT            } from '../../modules/local/snvphyl/vcf2snv_alignment'
include { PHYML                        } from '../../modules/local/snvphyl/phyml'
include { MAKE_SNV                     } from '../../modules/local/snvphyl/make_snv'

/*
========================================================================================
    IMPORT NF-CORE SUBWORKFLOWS
========================================================================================
*/

include { INPUT_CHECK                  } from './input_check'
include { FASTQC                       } from '../../modules/nf-core/fastqc/main'

/*
========================================================================================
    GROOVY FUNCTIONS
========================================================================================
*/

def add_empty_ch(input_ch) {
    def meta_seq_type = input_ch[0]
    return [ meta_seq_type, []]
}

// Define the filter function
def filter_and_define_tree(input_meta, snvAlignment, consolidated_bcfs) {
    def isolate_num = consolidated_bcfs.size() 
    def meta = input_meta
    if (isolate_num > 2) {
        return [ meta, snvAlignment ]
    } else {
        print("its me")
         return [ meta, []]
    }
}

def check_if_empty(phylm, empty_ch){
    print("got here")
    //when phylm is empty then empty_ch will be [seq_type:All_Isolates]
    def tree_ch = phylm.empty ? empty_ch : phylm
    if (tree_ch.startsWith("seq_type:")){
        return [empty_ch, []]
    }
    return [tree_ch]
}

// Define the filter function
def filter_and_define_tree2(input_meta, snvAlignment, consolidated_bcfs, phylogeneticTree) {
    def isolate_num = consolidated_bcfs.size() 
    def meta = input_meta
    if (isolate_num > 2) {
        return [ meta, phylogeneticTree ]
    } else {
         return [ meta, []]
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SNVPHYL {
    take:
        samplesheet // GRIPHIN.out.griphin_samplesheet
        reference   // GET_REFERENCE_SEQ.out.reference

    main:
        ch_versions = Channel.empty() // Used to collect the software versions

        //This helps convert what was given to griphin to a sample sheet with the paths to fastq files
        CONVERT_INPUT (
            samplesheet
        )
        ch_versions = ch_versions.mix(CONVERT_INPUT.out.versions)

        // SUBWORKFLOW: Read in samplesheet, validate and stage input files
        INPUT_CHECK (
            CONVERT_INPUT.out.updated_samplesheet
        )
        ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

        // Run FastQC
        FASTQC (
            INPUT_CHECK.out.reads
        )
        ch_versions = ch_versions.mix(FASTQC.out.versions.first())

        //1. index process takes 1 input channel as a argument
        INDEXING (
            reference
        )
        ch_versions = ch_versions.mix(INDEXING.out.versions)

        // Step 2: Join reference and INDEXING.out.ref_indexes by `meta.seq_type`
        ref_indexed_channel = INDEXING.out.ref_indexes.join(reference, by: [0])

        //2. find repeats process takes 1 input channel as a argument
        FIND_REPEATS (
            reference
        )
        ch_versions = ch_versions.mix(FIND_REPEATS.out.versions)

        // Try as I might nextflow foiled me at every attempt to get it to merge on seq_type without removing the id, so I have relented and removed it and then added it back after merging. 
        // need to use "combine" to allow multiple uses of INDEXING.out.ref_indexes without depletion. This approach effectively mimics a "non-consuming join" based on seq_type.And we filter to get the correct things after.
        smalt_ch = INPUT_CHECK.out.reads.combine(INDEXING.out.ref_indexes).filter{ meta_reads, reads, meta_ref_index, ref_fai, ref_sma, ref_smi -> 
            // Only keep pairs where `seq_type` matches
            meta_reads.seq_type == meta_ref_index.seq_type}.map { meta_reads, reads, meta_ref_index, ref_fai, ref_sma, ref_smi ->
                def meta = [:]
                meta.seq_type = meta_reads.seq_type
                meta.id = reads[0].getName().replaceAll("_1.trim.fastq.gz", "")
                // Format the output as required
                [ meta, reads, ref_fai, ref_sma, ref_smi ]}

        //3. smalt map process takes 2 input channels as arguments
        SMALT_MAP (
            smalt_ch
       )
        ch_versions = ch_versions.mix(SMALT_MAP.out.versions)

        //4. sorting and indexing bam files from smalt process takes 1 input channel as an arguments
        SORT_INDEX_BAMS (
            SMALT_MAP.out.bams
        )
        ch_versions = ch_versions.mix(SORT_INDEX_BAMS.out.versions)

        // collect all sorted bam files and separate them in their own channel by ST
        sort_indexed_bams_ch = SORT_INDEX_BAMS.out.sorted_bams.map { meta, sorted_bams -> [meta.seq_type, [meta, sorted_bams]] }  // Extract `seq_type` as key
            .groupTuple().map { seq_type, sorted_bams ->
            def meta = [seq_type: seq_type]
            def sorted_bams_files = sorted_bams.collect { it[1] }  // Collect all BAM files for this `seq_type`
            // Format as required: [ [meta], sorted_bams_file1, sorted_bams_file2, ... ]
            [meta] + [sorted_bams_files]}

        //5. Generating mapping_quality.txt file
        GENERATE_LINE_1 (
            sort_indexed_bams_ch
        )
        ch_versions = ch_versions.mix(GENERATE_LINE_1.out.versions)

        // Combine sorted bams and bam_lines by ST
        verifying_map_q_ch = sort_indexed_bams_ch.join(GENERATE_LINE_1.out.bam_lines_file, by: [0])

        VERIFYING_MAP_Q (
            verifying_map_q_ch.map{ meta, sorted_bams, bam_lines_file -> [ meta, sorted_bams ]},
            verifying_map_q_ch.map{ meta, sorted_bams, bam_lines_file -> bam_lines_file}.splitText()
        )
        ch_versions = ch_versions.mix(VERIFYING_MAP_Q.out.versions)
        
        // Only keep pairs where `seq_type` matches and format the output as required
        sorted_bams_with_ch = SORT_INDEX_BAMS.out.sorted_bams.map{meta, sorted_bams -> [[seq_type:meta.seq_type], sorted_bams]}.combine(ref_indexed_channel)
                .filter{ meta_bam, bam, meta_ref, ref_fai, ref_sma, ref_smi, reference -> meta_bam.seq_type == meta_ref.seq_type} 
                .map{meta_bam, bam, meta_ref, ref_fai, ref_sma, ref_smi, reference -> 
                        def meta = [:]
                        meta.seq_type = meta_bam.seq_type
                        meta.id = bam.getName().replaceAll("_sorted.bam", "")
                        [ meta, bam, ref_fai, ref_sma, ref_smi, reference ]}

        //6. freebays variant calling process takes 3 input channels as arguments. You can do without indexes, but then freebayes makes them so including
        FREEBAYES (
            sorted_bams_with_ch
        )
        ch_versions = ch_versions.mix(FREEBAYES.out.versions)

        //7. filter freebays variant file process takes 1 input channel as an argument
        FILTER_FREEBAYES (
            FREEBAYES.out.vcf_files
        )
        ch_versions = ch_versions.mix(FILTER_FREEBAYES.out.versions)

        // Zip up the freebayes vcf
        BGZIP_FREEBAYES_VCF(
            FILTER_FREEBAYES.out.filtered_vcf
        )
        ch_versions = ch_versions.mix(BGZIP_FREEBAYES_VCF.out.versions)

        //8. Convert vcf freebays variant file to bcf process takes 1 input channel as an argument
        FREEBAYES_VCF_TO_BCF (
            BGZIP_FREEBAYES_VCF.out.filtered_zipped_vcf
        )
        ch_versions = ch_versions.mix(FREEBAYES_VCF_TO_BCF.out.versions)

        //9. mplileup process takes 1 input channel as argument. You can do without indexes, but then mpileup makes them so including for speed
        MPILEUP (
            sorted_bams_with_ch
        )
        ch_versions = ch_versions.mix(MPILEUP.out.versions)

        // Zip up the mpileup vcf
        BGZIP_MPILEUP_VCF (
            MPILEUP.out.mpileup
        )
        ch_versions = ch_versions.mix(BGZIP_MPILEUP_VCF.out.versions)

        //10. mplileup variant calls takes 1 input channel as an argument
        BCFTOOLS_CALL (
            BGZIP_MPILEUP_VCF.out.mpileup_zipped
        )
        ch_versions = ch_versions.mix(BCFTOOLS_CALL.out.versions)

        //Joining channels of multiple outputs
        combined_ch = BCFTOOLS_CALL.out.mpileup_bcf.join(FREEBAYES_VCF_TO_BCF.out.filtered_bcf, by: [0])

        //11. consolidate variant calling files process takes 2 input channels as arguments
        CONSOLIDATE_BCFS (
            combined_ch
        )
        ch_versions = ch_versions.mix(CONSOLIDATE_BCFS.out.versions)
        
        // collect all filter densities and separate them in their own channel by ST
        consolidated_fds_ch = CONSOLIDATE_BCFS.out.filtered_densities.map { meta, consolidated_fds -> [meta.seq_type, [meta, consolidated_fds]] }  // Extract `seq_type` as key
            .groupTuple().map{ seq_type, consolidated_fds ->
            def meta = [seq_type: seq_type]
            def consolidated_fds_files = consolidated_fds.collect { it[1] }  // Collect all BAM files for this `seq_type`
            // Format as required: [ [meta], bcf_file1, bcf_file2, ... ]
            [meta] + [consolidated_fds_files]}

        // using the filter densities channel combine with bed file and filter them into their own channel by ST
        consolidate_filtered_densities_ch = consolidated_fds_ch.combine(FIND_REPEATS.out.repeats_bed_file).filter{ meta_fd, filtered_densities, meta_bed, repeats_bed_file -> 
            // Only keep pairs where `seq_type` matches
            meta_fd.seq_type == meta_bed.seq_type}.map { meta_fd, filtered_densities, meta_bed, repeats_bed_file ->
                def meta = [:]
                meta.seq_type = meta_fd.seq_type
                // Format the output as required
                [ meta, filtered_densities, repeats_bed_file ]}
        
        // Concat filtered densities to make new invalid_postions
        CONSOLIDATE_FILTERED_DENSITY (
            consolidate_filtered_densities_ch
        )
        ch_versions = ch_versions.mix(CONSOLIDATE_FILTERED_DENSITY.out.versions)

        // collect all bcf files and separate them in their own channel by ST
        consolidated_bcfs_ch = CONSOLIDATE_BCFS.out.consolidated_bcfs.map { meta, consolidated_bcfs -> [meta.seq_type, [meta, consolidated_bcfs]] }  // Extract `seq_type` as key
            .groupTuple().map{ seq_type, consolidated_bcfs ->
            def meta = [seq_type: seq_type]
            def consolidated_bcfs_files = consolidated_bcfs.collect { it[1] }  // Collect all BAM files for this `seq_type`
            // Format as required: [ [meta], bcf_file1, bcf_file2, ... ]
            [meta] + [consolidated_bcfs_files]}

        // Making string that looks like... this is needed for the next process
        //--consolidate_vcf 2021JQ-00457-WAPHL-M5130-211029=2021JQ-00457-WAPHL-M5130-211029_consolidated.bcf --consolidate_vcf 2021JQ-00459-WAPHL-M5130-211029=2021JQ-00459-WAPHL-M5130-211029_consolidated.bcf --consolidate_vcf 2021JQ-00460-WAPHL-M5130-211029=2021JQ-00460-WAPHL-M5130-211029_consolidated.bcf
        GENERATE_LINE_2 (
            consolidated_bcfs_ch
        )
        ch_versions = ch_versions.mix(GENERATE_LINE_2.out.versions)

        // collect all sorted bcf index files and separate them into their own channel by ST
        consolidate_bcf_indexes_ch = CONSOLIDATE_BCFS.out.consolidated_bcf_index.map{ meta, consolidated_bcf_indexes -> [meta.seq_type, [meta, consolidated_bcf_indexes]] }  // Extract `seq_type` as key
            .groupTuple().map{ seq_type, consolidated_bcf_indexes ->
            def meta = [seq_type: seq_type]
            def consolidated_bcf_indexes_files = consolidated_bcf_indexes.collect { it[1] }  // Collect all BAM files for this `seq_type`
            // Format as required: [ [meta], [bcf_file1, bcf_file2, ...] ]
            [meta] + [consolidated_bcf_indexes_files]}
        
        //get everything all together!
        vcf2snv_alignment_ch = GENERATE_LINE_2.out.consolidation_line.join(consolidated_bcfs_ch, by: [0])
                                .join(CONSOLIDATE_FILTERED_DENSITY.out.new_invalid_positions.map{ meta, new_invalid_positions -> [[seq_type:meta.seq_type], new_invalid_positions]}, by: [0])
                                .join(consolidate_bcf_indexes_ch, by: [0])
                                .join(reference, by: [0])

        // Get line out of file we just made that has the --consolidate_vcf line...
        //13. consolidate variant calling files process takes 2 input channels as arguments
        VCF2SNV_ALIGNMENT ( 
            vcf2snv_alignment_ch.map{ meta, consolidation_line, consolidated_bcfs, new_invalid_positions, consolidate_bcf_indexes, reference -> [ meta, consolidation_line ] }.splitText(),
            vcf2snv_alignment_ch.map{ meta, consolidation_line, consolidated_bcfs, new_invalid_positions, consolidate_bcf_indexes, reference -> [ meta, consolidated_bcfs ] },
            vcf2snv_alignment_ch.map{ meta, consolidation_line, consolidated_bcfs, new_invalid_positions, consolidate_bcf_indexes, reference -> [ meta, new_invalid_positions ] },
            vcf2snv_alignment_ch.map{ meta, consolidation_line, consolidated_bcfs, new_invalid_positions, consolidate_bcf_indexes, reference -> [ meta, reference ] },
            vcf2snv_alignment_ch.map{ meta, consolidation_line, consolidated_bcfs, new_invalid_positions, consolidate_bcf_indexes, reference -> [ meta, consolidate_bcf_indexes ] }
        )
        ch_versions = ch_versions.mix(VCF2SNV_ALIGNMENT.out.versions)

        //14. Filter Stats
        FILTER_STATS (
            VCF2SNV_ALIGNMENT.out.snvTable
        )
        ch_versions = ch_versions.mix(FILTER_STATS.out.versions)

        // create empty channel with meta information for cases where the snvmatrix is empty --> just trying to keep the pipeline chugging along to the end.
        empty_ch = VCF2SNV_ALIGNMENT.out.snvAlignment.map{ it -> add_empty_ch(it) }
        make_snv_ch = VCF2SNV_ALIGNMENT.out.snvAlignment.join(VCF2SNV_ALIGNMENT.out.emptyMatrix, by: [0])

        //15. Make SNVMatix.tsv
        MAKE_SNV (
            make_snv_ch
        )
        ch_versions = ch_versions.mix(MAKE_SNV.out.versions)

        // Filter STs that don't have > 2 samples as tree building will fail, but we will want the SNV Matrix. If empty and create a placeholder empty channel to keep down stream processes happy.
        phylm_ch = VCF2SNV_ALIGNMENT.out.snvAlignment.join(consolidated_bcfs_ch, by: [0]).filter{ meta, snvAlignment, consolidated_bcfs -> consolidated_bcfs.size() >= 2}
            .map { meta, snvAlignment, consolidated_bcfs -> [meta, snvAlignment]}

        //16. Using phyml to build tree process takes 1 input channel as an argument
        PHYML (
            phylm_ch
        )
        ch_versions = ch_versions.mix(PHYML.out.versions)

        // A bunch of nonsense that could have been a simple if/else statement, but nextflow is idiotic and doesn't allow that.
        // TL;DR: If not enough samples to build a tree then return empty channel, else return phyml channel
        // For when there are not enough samples to build a tree, we need to keep the process running and return an empty channel with the correct meta information.
        phylogeneticTree1 = VCF2SNV_ALIGNMENT.out.snvAlignment.join(consolidated_bcfs_ch, by: [0]).filter{ meta, snvAlignment, consolidated_bcfs -> consolidated_bcfs.size() < 2}
            .map { meta, snvAlignment, consolidated_bcfs -> [meta, []]}
    
        // When there are enough samples to build a tree, we need to return the PHYML.out.phylogeneticTree channel.
        phylogeneticTree2 = VCF2SNV_ALIGNMENT.out.snvAlignment.join(consolidated_bcfs_ch, by: [0])
            .filter{ meta, snvAlignment, consolidated_bcfs -> consolidated_bcfs.size() >= 2}.join(PHYML.out.phylogeneticTree, by: [0]).map{ meta, snvAlignment, consolidated_bcfs, tree -> [meta, tree]}

        phylogeneticTree = phylogeneticTree1.concat(phylogeneticTree2)

    emit:
        versions         = ch_versions // channel: [ versions.yml ]
        snvMatrix        = MAKE_SNV.out.snvMatrix
        vcf2core         = VCF2SNV_ALIGNMENT.out.vcf2core
        phylogeneticTree = phylogeneticTree

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
