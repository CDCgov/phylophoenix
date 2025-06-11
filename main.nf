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
    //if you use --no_all phylophoenix assumes you want to do it by st and will set to true
    if (params.no_all==true) {
        by_st = true
    } else {
        by_st = params.by_st //this is the default of false
    }
    // Check input path parameters to see if they exist
    if (params.input != null ) {  // if a samplesheet is passed
        // allow input to be relative, turn into string and strip off the everything after the last backslash to have remainder of as the full path to the samplesheet. 
        //input_samplesheet_path = Channel.fromPath(params.input, relative: true).map{ [it.toString().replaceAll(/([^\/]+$)/, "").replaceAll(/\/$/, "") ] }
        input_samplesheet_path = Channel.fromPath(params.input, relative: true)
        if (params.indir != null ) { //if samplesheet is passed and an input directory exit
            exit 1, 'You need EITHER an input samplesheet or a directory! Just pick one.' 
        } else { // if only samplesheet is passed check to make sure input is an actual file
            indir = []
            def checkPathParamList = [ params.input ]
            for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
        }
    } else { // if no samplesheet is passed
        if (params.indir != null ) { // if no samplesheet is passed, but an input directory is given
            input_samplesheet_path = []
            def checkPathParamList = [ params.indir ]
            for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
            indir = params.indir
        } else { // if no samplesheet is passed and no input directory is given
            exit 1, 'You need EITHER an input samplesheet or a directory!' 
        }
    }

    if (params.force==true){
        print("You passed --force, so samples that failed QC in PHoeNIx are going to be included in the analysis! This can produce unexpected results, DO NOT USE THIS FLAG UNLESS YOU KNOW WHAT YOU ARE DOING!")
    }

    main:
        PHYLOPHOENIX ( input_samplesheet_path, indir, by_st )
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
