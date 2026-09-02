#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    cdcgov/phylophoenix
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/cdcgov/phylophoenix
    Slack  : https://staph-b-dev.slack.com/channels/phoenix-h-dev
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

WorkflowMain.initialise(workflow, params, log)


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PHYLOPHOENIX } from './workflows/phylophoenix'

//
// WORKFLOW: Run main nf-core/phylophoenix analysis pipeline
//
workflow PHYLOPHOENIX_WF {
    ch_versions = Channel.empty()
    //if you use --no_all phylophoenix assumes you want to do it by st and will set to true
    if (params.no_all==true) {
        by_st = true
    } else {
        by_st = params.by_st //this is the default of false
    }

    if (params.use_secondary_mlst==true && params.by_st==false) {
        exit 1, "you passed --use_secondary_mlst but did not pass --by_st. If you want to use the secondary MLST scheme, you must also specify --by_st."
    }

    // check terra param make suer its a boolean, if not exit with error
    if (!(params.terra instanceof Boolean)) {  exit 1, "ERROR: params.terra must be true or false, got: ${params.terra}"}

    // Confirm that the reference genome parameter is a gzip-compressed file if it is provided
    if (params.ref_genome && params.ref_genome != 'null' && params.ref_genome != '') {
        def ref_genome_file = file(params.ref_genome)
        if (!ref_genome_file.name.toLowerCase().endsWith('.gz')) { error "ERROR: --ref_genome must be a gzip-compressed file ending in '.gz'. Got: ${params.ref_genome}" }
        if (!ref_genome_file.exists()) { error "ERROR: --ref_genome file not found: ${params.ref_genome}" }
    }

    // // Check input path parameters to see if they exist
    // if (params.input != null ) {  // if a samplesheet is passed
    //     // allow input to be relative, turn into string and strip off the everything after the last backslash to have remainder of as the full path to the samplesheet. 
    //     //input_samplesheet_path = Channel.fromPath(params.input, relative: true).map{ [it.toString().replaceAll(/([^\/]+$)/, "").replaceAll(/\/$/, "") ] }
    //     //input_samplesheet_path = Channel.fromPath(params.input, relative: true)
    //     if (params.input) { input_samplesheet_path = file(params.input) }
    //     if (params.indir != null ) { //if samplesheet is passed and an input directory exit
    //         exit 1, 'You need EITHER an input samplesheet or a directory! Just pick one.' 
    //     } else { // if only samplesheet is passed check to make sure input is an actual file
    //         indir = null  //keep input directory null if not passed
    //         def checkPathParamList = [ params.input ]
    //         for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
    //     }
    // } else { // if no samplesheet is passed
    //     if (params.indir != null ) { // if no samplesheet is passed, but an input directory is given
    //         input_samplesheet_path = []
    //         def checkPathParamList = [ params.indir ]
    //         for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
    //         indir = params.indir
    //     } else { // if no samplesheet is passed and no input directory is given
    //         exit 1, 'You need EITHER an input samplesheet or a directory!' 
    //     }
    // }

    // Check mandatory parameters
    ch_versions = Channel.empty() // Used to collect the software versions
    // Check input path parameters to see if they exist
    if (params.input != null ) {  // if a samplesheet is passed
        //input_samplesheet_path = Channel.fromPath(params.input, relative: true)
        if (params.indir != null ) { //if samplesheet is passed and an input directory exit
            exit 1, 'You need EITHER an input samplesheet or a directory! Just pick one.' 
        } else { // if only samplesheet is passed check to make sure input is an actual file
            def checkPathParamList = [ params.input ]
            for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
            ch_input_indir = null //keep input directory null if not passed
            // get full path for input and make channel
            if (params.input) { ch_input = file(params.input) }
        }
    } else {
/*        if (params.indir != null ) { // if no samplesheet is passed, but an input directory is given
            ch_input = null //keep samplesheet input null if not passed
            def checkPathParamList = [ params.indir ]
            for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
            ch_input_indir = Channel.fromPath(params.indir, relative: true, type: 'dir')
        } else { // if no samplesheet is passed and no input directory is given
            exit 1, 'For --mode UPDATE_CDC_PHOENIX: You need EITHER an input samplesheet or a directory!' 
        }
    }*/
        if (params.indir != null ) {

            def checkPathParamList = [ params.indir ]
            for (param in checkPathParamList) {
                if (param) { file(param, checkIfExists: true) }
            }

            //ch_input_indir = Channel.fromPath(params.indir, relative: true, type: 'dir')

            // Build expected samplesheet path
            def samplesheet_path = "${params.indir}/Directory_samplesheet.csv"

            // Check it exists with a helpful error
            if ( !file(samplesheet_path).exists() ) {
                exit 1, "Expected samplesheet not found: ${samplesheet_path}\nMake sure Directory_samplesheet.csv exists inside --indir."
            }

            // Create channel input
            ch_input = file(samplesheet_path)
            params.indir = null // Set indir to null to avoid confusion later in the workflow since we have the samplesheet path now
//            ch_input_indir = null // Set input directory to null since we have the samplesheet path now
            params.input = samplesheet_path // Set input to the samplesheet path for consistency in the workflow
        } else {
            exit 1, 'For --mode UPDATE_CDC_PHOENIX: You need EITHER an input samplesheet or a directory!'
        }
    }

    if (params.force==true){
        print("You passed --force, so samples that failed QC in PHoeNIx are going to be included in the analysis! This can produce unexpected results, DO NOT USE THIS FLAG UNLESS YOU KNOW WHAT YOU ARE DOING!")
    }

    main:
        PHYLOPHOENIX ( ch_input, by_st, ch_versions )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
//
workflow {
    PHYLOPHOENIX_WF ()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
