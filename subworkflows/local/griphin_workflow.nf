//
// Subworkflow: one of the workflows to generate a report
//

include { GRIPHIN            } from '../../modules/local/griphin'
include { CREATE_SAMPLESHEET } from '../../modules/local/create_samplesheet'
include { REMOVE_FAILURES    } from '../../modules/local/remove_failures'

workflow GRIPHIN_WORKFLOW {
    take:
        input_samplesheet_path // channel: tuple val(meta), path('*.json'): FASTP_TRIMD.out.json --> PHOENIX_EXQC.out.paired_trmd_json
        indir

    main:
        ch_versions = Channel.empty() // Used to collect the software versions

        // Check if input samplesheet or input directory has passed, then check if a control list was passed
        // we have to do all this to make sure paths can be relative
        if (params.input != null) { // if samplesheet is passed
            if (params.blind_list != null){ // if control list is passed allow it to be relative
                // Allow control list to be relative
                blind_path = Channel.fromPath(params.blind_list, relative: true)
                // Create report
                GRIPHIN (
                    input_samplesheet_path, params.ardb, params.prefix, blind_path, params.coverage, params.cdc
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            } else {
                // Create report
                GRIPHIN (
                    input_samplesheet_path, params.ardb, params.prefix, [], params.coverage, params.cdc
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            }
            directory_samplesheet = GRIPHIN.out.griphin_samplesheet
        } else { // if no samplesheet is passed the we will make one
            // allow input directory to be relative
            inputdir_path = Channel.fromPath(indir, relative: true, type: 'dir') // this same path is needed to make the samplesheet

            // Create samplesheet - while GRiPHin can create a samplesheet for you, due to nextflow/softlinks etc this results in failures at the create_meta step. 
            // so we are just using another process to create the samplesheet :)
            // sample_id,/path/sample_folder
            CREATE_SAMPLESHEET (
                inputdir_path
            )
            ch_versions = ch_versions.mix(CREATE_SAMPLESHEET.out.versions)

            if (params.blind_list != null){ // if control list is passed allow it to be relative
                // Allow control list to be relative
                blind_path = Channel.fromPath(params.blind_list, relative: true)
                // Create report
                GRIPHIN (
                    CREATE_SAMPLESHEET.out.samplesheet, params.ardb, params.prefix, blind_path, params.coverage, params.cdc
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            } else {
                // Create report
                GRIPHIN (
                    CREATE_SAMPLESHEET.out.samplesheet, params.ardb, params.prefix, [], params.coverage, params.cdc
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            }
            directory_samplesheet = CREATE_SAMPLESHEET.out.samplesheet
        }

        // Identify samples failed PHX specs
        REMOVE_FAILURES(
            GRIPHIN.out.griphin_tsv_report, directory_samplesheet
        )
        ch_versions = ch_versions.mix(REMOVE_FAILURES.out.versions)

        if (params.force==false){
            final_directory_samplesheet = REMOVE_FAILURES.out.cleaned_dir_samplesheet
        } else {
            final_directory_samplesheet = directory_samplesheet
        }

        //ids_to_remove_ch = REMOVE_FAILURES.out.failured_ids.splitCsv( header:false, sep:',' )
        // add in the reads to the channel
        //filtered_reads = reads.map{reads -> [ reads ] }.combine(ids_to_remove_ch).map{reads, ids_to_remove_ch -> filter_reads(reads, ids_to_remove_ch) }.flatten()

    emit:
        griphin_report        = GRIPHIN.out.griphin_report
        griphin_tsv_report    = GRIPHIN.out.griphin_tsv_report  
        directory_samplesheet = final_directory_samplesheet
        versions              = ch_versions // channel: [ versions.yml ]
}