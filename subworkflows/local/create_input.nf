//
// workflow handles taking in either a samplesheet or directory and creates correct channels for scaffolds entry point
//

// for cdc_phoenix, phoenix entry
include { SAMPLESHEET_CHECK as SAMPLESHEET_CHECK          } from '../../modules/local/samplesheet_check'
// for update entry
include { COLLECT_SAMPLE_FILES  }                           from '../../modules/local/updater/collect_sample_files'
include { COLLECT_PROJECT_FILES }                           from '../../modules/local/updater/collect_project_files'
include { CREATE_FAIRY_FILE     }                           from '../../modules/local/updater/create_fairy_file'

// ANSI escape code for orange (bright yellow)
def orange = '\033[38;5;208m'
def reset = '\033[0m'

workflow CREATE_INPUT {
    take:
        samplesheet  // params.input

    main:
        ch_versions = Channel.empty() // Used to collect the software versions
        meta_ch = Channel.fromPath(samplesheet).splitCsv( header:true, sep:',' ).map{ create_samplesheet_meta(it) }.unique()

        SAMPLESHEET_CHECK (
            samplesheet, false, false, true, meta_ch
        )
        ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)

        samplesheet = SAMPLESHEET_CHECK.out.csv.first()
        samplesheet_meta_ch = SAMPLESHEET_CHECK.out.csv_by_dir.flatten().map{ it -> transformSamplesheets(it)}

        // To make things backwards compatible we need to check if the file_integrity sample is there and if not create it.
        file_integrity_exists = samplesheet.splitCsv( header:true, sep:',' ).map{ it -> check_file_integrity(it) }.filter{meta, clean_path, fairy_exists -> fairy_exists == false }

        CREATE_FAIRY_FILE (
            file_integrity_exists, false
        )
        ch_versions = ch_versions.mix(CREATE_FAIRY_FILE.out.versions)

        directory_ch = samplesheet.splitCsv( header:true, sep:',' ).map{ it -> create_dir_channels(it) }

        //adding meta.id to end of dir - otherwise too many files are copied and it takes forever. 
        sample_directory_ch = samplesheet.splitCsv( header:true, sep:',' ).map{ it -> create_sample_dir_channels(it) }

        // pulling all the necessary sample level files into channels
        COLLECT_SAMPLE_FILES (
            sample_directory_ch
        )
        ch_versions = ch_versions.mix(COLLECT_SAMPLE_FILES.out.versions)

        //collect all fairy files and then recreate meta groups with flatten and buffer.
        // Was having issues with this first version not cutting files returned to a single file causing cname collisons in GRiPHiN.
        file_integrity_ch = CREATE_FAIRY_FILE.out.created_fairy_file.collect().ifEmpty([]).combine(COLLECT_SAMPLE_FILES.out.fairy_summary.collect().ifEmpty([])).flatten().buffer(size:2)

        //combine reads to get into one channel
        combined_reads_ch = COLLECT_SAMPLE_FILES.out.read1.join(COLLECT_SAMPLE_FILES.out.read2, by: [0]).map{ meta, read1, read2 -> [meta, [read1, read2]]}
        // get other files
        filtered_renamed_scaffolds_ch = COLLECT_SAMPLE_FILES.out.renamed_scaffolds
        filtered_scaffolds_ch         = COLLECT_SAMPLE_FILES.out.scaffolds
        filtered_gff_ch               = COLLECT_SAMPLE_FILES.out.gff
        filtered_faa_ch               = COLLECT_SAMPLE_FILES.out.faa
        line_summary_ch               = COLLECT_SAMPLE_FILES.out.summary_line
        filtered_synopsis_ch          = COLLECT_SAMPLE_FILES.out.synopsis
        filtered_taxonomy_ch          = COLLECT_SAMPLE_FILES.out.tax
        filtered_gamma_pf_ch          = COLLECT_SAMPLE_FILES.out.gamma_pf
        filtered_gamma_hv_ch          = COLLECT_SAMPLE_FILES.out.gamma_hv
        filtered_gamma_ar_ch  = COLLECT_SAMPLE_FILES.out.gamma_ar.combine(Channel.fromPath(params.ardb))
                                    .map{ meta, gamma_ar, ardb -> previous_updater_check(meta, gamma_ar, ardb, "gamma") }
        filtered_amrfinder_ch = COLLECT_SAMPLE_FILES.out.amrfinder_report.combine(Channel.fromPath(params.amrfinder_db))
                                    .map{ meta, amrfinder_report, amrfinder_db -> previous_updater_check(meta, amrfinder_report, amrfinder_db, "amrfinder") }
        filtered_assembly_ratio_ch = COLLECT_SAMPLE_FILES.out.assembly_ratio.combine(Channel.fromPath(params.ncbi_assembly_stats))
                                    .map{ meta, assembly_ratio, ncbi_stats -> previous_updater_check(meta, assembly_ratio, ncbi_stats, "ncbi_stats_ratio") }
        filtered_gc_content_ch = COLLECT_SAMPLE_FILES.out.gc_content.combine(Channel.fromPath(params.ncbi_assembly_stats))
                                    .map{ meta, gc_content, ncbi_stats -> previous_updater_check(meta, gc_content, ncbi_stats, "ncbi_stats_gc") }
        filtered_srst2_ar_ch = COLLECT_SAMPLE_FILES.out.srst2_ar.combine(Channel.fromPath(params.ardb))
                                    .map{ meta, srst2_ar, ardb -> previous_updater_check(meta, srst2_ar, ardb, "srst2") }

        filtered_trimd_kraken_bh_ch        = COLLECT_SAMPLE_FILES.out.trimd_kraken_bh
        filtered_trimd_krona_ch            = COLLECT_SAMPLE_FILES.out.trimd_kraken_krona
        filtered_trimd_kraken_report_ch    = COLLECT_SAMPLE_FILES.out.trimd_kraken_report
        filtered_wtasmbld_kraken_bh_ch     = COLLECT_SAMPLE_FILES.out.wtasmbld_kraken_bh
        filtered_wtasmbld_krona_ch         = COLLECT_SAMPLE_FILES.out.wtasmbld_kraken_krona
        filtered_wtasmbld_kraken_report_ch = COLLECT_SAMPLE_FILES.out.wtasmbld_kraken_report
        filtered_asmbld_kraken_bh_ch       = COLLECT_SAMPLE_FILES.out.asmbld_kraken_bh
        filtered_asmbld_krona_ch           = COLLECT_SAMPLE_FILES.out.asmbld_kraken_krona
        filtered_asmbld_kraken_report_ch   = COLLECT_SAMPLE_FILES.out.asmbld_kraken_report
        filtered_busco_short_summary_ch    = COLLECT_SAMPLE_FILES.out.busco_short_summary
        filtered_trimmed_stats_ch          = COLLECT_SAMPLE_FILES.out.trimmed_stats
        filtered_raw_stats_ch              = COLLECT_SAMPLE_FILES.out.raw_stats
        filtered_quast_ch                  = COLLECT_SAMPLE_FILES.out.quast_report
        filtered_ani_ch                    = COLLECT_SAMPLE_FILES.out.ani
        filtered_ani_best_hit_ch           = COLLECT_SAMPLE_FILES.out.ani_best_hit
        filtered_combined_mlst_ch          = COLLECT_SAMPLE_FILES.out.combined_mlst

        //species specific files
        shigapass_files_ch = COLLECT_SAMPLE_FILES.out.shigapass_output
        centar_files_ch = COLLECT_SAMPLE_FILES.out.centar_output
        //readme files
        readme_files_ch = COLLECT_SAMPLE_FILES.out.readme

        summary_files_ch = samplesheet.flatten().splitCsv( header:true, sep:',' ).map{ it -> create_summary_files_channels(it) }
                            .map{meta, griphin_excel, griphin_tsv, phoenix_tsv, pipeline_info -> [[project_id:meta.project_id], griphin_excel, griphin_tsv, phoenix_tsv, pipeline_info]}.unique()

        // pulling all the necessary project level files into channels
        COLLECT_PROJECT_FILES (
            summary_files_ch, true
        )
        ch_versions = ch_versions.mix(COLLECT_PROJECT_FILES.out.versions)

        griphin_excel_ch = COLLECT_PROJECT_FILES.out.griphin_excel
        griphin_tsv_ch = COLLECT_PROJECT_FILES.out.griphin_tsv
        phoenix_tsv_ch = COLLECT_PROJECT_FILES.out.phoenix_tsv.map{it -> add_entry_meta(it)}
        pipeline_info_ch = COLLECT_PROJECT_FILES.out.software_versions_file

        valid_samplesheet = samplesheet // still need to check this file

    emit:
        //project level summary files
        griphin_excel_ch   = griphin_excel_ch
        griphin_tsv_ch     = griphin_tsv_ch
        phoenix_tsv_ch     = phoenix_tsv_ch
        pipeline_info_ch   = pipeline_info_ch
        directory_ch       = directory_ch
        valid_samplesheet  = valid_samplesheet
        versions           = ch_versions
        pipeline_info      = pipeline_info_ch

        //species specific files
        centar             = centar_files_ch
        shigapass          = shigapass_files_ch
        //updater
        readme             = readme_files_ch
        samplesheet_meta_ch = samplesheet_meta_ch

        // sample specific files
        renamed_scaffolds      = filtered_renamed_scaffolds_ch
        filtered_scaffolds     = filtered_scaffolds_ch      // channel: [ meta, [ scaffolds_file ] ]
        reads                  = combined_reads_ch
        taxonomy               = filtered_taxonomy_ch
        prokka_gff             = filtered_gff_ch
        prokka_faa             = filtered_faa_ch
        fairy_outcome          = file_integrity_ch
        line_summary           = line_summary_ch // need non-filtered to make summary files will all samples in project folder
        synopsis               = filtered_synopsis_ch
        ani                    = filtered_ani_ch
        ani_best_hit           = filtered_ani_best_hit_ch
        ncbi_report            = filtered_amrfinder_ch
        gamma_ar               = filtered_gamma_ar_ch
        srst2_ar               = filtered_srst2_ar_ch
        gamma_pf               = filtered_gamma_pf_ch
        gamma_hv               = filtered_gamma_hv_ch
        assembly_ratio         = filtered_assembly_ratio_ch
        gc_content             = filtered_gc_content_ch
        k2_trimd_bh_summary    = filtered_trimd_kraken_bh_ch
        k2_trimd_krona         = filtered_trimd_krona_ch
        k2_trimd_report        = filtered_trimd_kraken_report_ch
        k2_wtasmbld_bh_summary = filtered_wtasmbld_kraken_bh_ch
        k2_wtasmbld_krona      = filtered_wtasmbld_krona_ch
        k2_wtasmbld_report     = filtered_wtasmbld_kraken_report_ch
        k2_asmbld_bh_summary   = filtered_asmbld_kraken_bh_ch
        k2_asmbld_krona        = filtered_asmbld_krona_ch
        k2_asmbld_report       = filtered_asmbld_kraken_report_ch
        busco_short_summary    = filtered_busco_short_summary_ch
        fastp_total_qc         = filtered_trimmed_stats_ch
        raw_stats              = filtered_raw_stats_ch
        quast_report           = filtered_quast_ch
        combined_mlst          = filtered_combined_mlst_ch // for centar entry

}

/*========================================================================================
    GROOVY FUNCTIONS
========================================================================================
*/

def previous_updater_check(meta, ar_file, ardb, type) {
    //if you run updater with the same AR db as was run before you will get a file name collision in the CREATE_AND_UPDATE_README step
    // this function will filter out the files that have already been processed with the same AR db date to keep the file name collision from happening
    def orange = '\033[38;5;208m'
    def reset = '\033[0m'
    def patterns = [ gamma: /ResGANNCBI_(\d{8})_srst2\.fasta/, amrfinder: /amrfinderdb_v\d{1}\.\d{1}_(\d{8})\.\d{1}\.tar\.gz/, ncbi_stats_ratio: /_Assembly_stats_(\d{8})\.txt/ , ncbi_stats_gc: /_Assembly_stats_(\d{8})\.txt/, srst2: /ResGANNCBI_(\d{8})_srst2\.fasta/ ]
    def ardbDate = (ardb.getName() =~ patterns[type])[0][1] // get ar date
    def isList = ar_file instanceof List // check if the input is a list or a single file
    // Filter to keep only gamma/amrfinder files that do not contain the extracted date
    def matchingFiles = isList ? ar_file.findAll { !it.getName().contains(ardbDate) } : (!ar_file.getName().contains(ardbDate) ? ar_file : null)
    def filteredFiles = isList ? ar_file.findAll { it.getName().contains(ardbDate) } : (ar_file.getName().contains(ardbDate) ? ar_file : null)
    //print warning if the file has already been processed with the same AR db date
    if (params.mode_upper == "UPDATE_PHOENIX") {
        if (filteredFiles) {
            def cleanedFilename = filteredFiles[0].toString().split('/').last()
            def replacements = [ gamma: [".gamma", "${meta.id}_"], amrfinder: ["amrfinderdb_", ".tar.gz"], ncbi_stats_ratio: ["_Assembly_stats_", ".txt"], ncbi_stats_gc: ["_GC_content_", ".txt"], srst2: ["__fullgenes__ResGANNCBI_", "__srst2__results.txt"]]
            replacements[type].each { cleanedFilename = cleanedFilename.replace(it, "") }
            def outputFiles = [ gamma: "${meta.id}_ResGANNCBI_${ardbDate}_srst2.gamma", amrfinder: "${meta.id}_all_genes_${ardbDate}.tsv", ncbi_stats_ratio: "${meta.id}_Assembly_ratio_${ardbDate}.txt", ncbi_stats_gc: "${meta.id}_GC_content_${ardbDate}.txt", srst2: "${meta.id}__fullgenes__ResGANNCBI_${ardbDate}_srst2__results.txt"]
            println("${orange}WARNING: ${meta.id} already had updater run with AR db date ${cleanedFilename}, ${outputFiles[type]} will be overwritten.${reset}")
        return [meta, isList && matchingFiles.size() == 1 ? matchingFiles[0] : matchingFiles]
        } else {
            return [meta, isList && filteredFiles.size() == 1 ? matchingFiles[0] : matchingFiles]
        }
    }
}

// Function to get list of [sample:, directory: ] or [ meta, [ fastq_1, fastq_2 ] ] to [ project_id: full_project_id:]
def create_samplesheet_meta(LinkedHashMap row) {
    def meta = [:]
    if (row.directory) { //[sample:, directory: ] 
        // Use directory-based logic
        meta.project_id      = row.directory.toString().split('/')[-2]
        meta.full_project_id = new File(row.directory).getParent().replace("[", "")
    } else if (row.fastq_1) {  //[ meta, [ fastq_1, fastq_2 ] ] 
        // Use fastq_1-based logic
        meta.full_project_id = new File(row.fastq_1).parent
        meta.project_id      = new File(row.fastq_1).parentFile.name
    }
    return meta 
}

def transformSamplesheets(input_ch) {
    def meta = [:] // create meta array
    def matcher = input_ch.name =~ /valid_(.+)\.csv$/ // Extract project_id from filename pattern: everything between valid_ and .csv
    meta.project_id = matcher ? matcher[0][1] : "unknown"
    return [meta, input_ch]
}

def check_file_integrity(LinkedHashMap row) {
    def meta = [:] // create meta array
    meta.id = row.sample
    //meta.project_id = row.directory.toString().split('/')[-2]
    //meta.project_id = row.directory
    def clean_path = row.directory.toString().endsWith("/") ? row.directory.toString()[0..-2] : row.directory.toString()
    meta.project_id = new File(clean_path).getParent()
    def pattern = "*_summary.txt"
    // Convert the wildcard pattern to regex: "*_summary.txt" to ".*_summary\.txt"
    def regexPattern = pattern.replace("*", ".*").replace("?", ".")
    File dir = new File(clean_path + "/file_integrity/")
    // List files matching the regex pattern
    def files = dir.listFiles { file -> file.name ==~ /${regexPattern}/ }
    //if (files && files.length > 0) {
    if (files) {
        /*files.each { file ->
            def lines = file.readLines()
            if (lines.size() != 5) {
                exit 1, "ERROR: File '${file.name}' in '${file.parent}' has ${lines.size()} lines instead of 5, this will cause errors downstream, please rerun with phx >2.2.0 and rerun."
            }
        }*/
        return [ meta, clean_path, true ]
    } else {
        return [ meta, clean_path, false ]
    }
}

// Function to get list of [ meta, [ directory ] ]
def create_dir_channels(LinkedHashMap row) {
    def meta = [:] // create meta array
    meta.id = row.sample
    //meta.project_id = row.directory.toString().split('/')[-2]
    //meta.project_id = row.directory
    def clean_path = row.directory.toString().endsWith("/") ? row.directory.toString()[0..-2] : row.directory.toString()
    def cleaned_path = new File(clean_path).getParent()
    meta.project_id = cleaned_path
    return [ meta, cleaned_path ]
}

// Function to get list of [ meta, [ directory ] ]
def create_sample_dir_channels(LinkedHashMap row) {
    def meta = [:] // create meta array
    meta.id = row.sample
    //meta.project_id = row.directory.toString().split('/')[-2]
    //meta.project_id = row.directory
    def clean_path = row.directory.toString().endsWith("/") ? row.directory.toString()[0..-2] : row.directory.toString()
    meta.project_id = new File(clean_path).getParent()
    return [ meta, clean_path ]
}

