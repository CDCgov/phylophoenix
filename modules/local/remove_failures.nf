process REMOVE_FAILURES {
    tag "$summary"
    label 'process_single'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    path(summary)
    path(directory_samplesheet)

    output:
    path('failed_ids.txt'),            emit: failured_ids
    path('Directory_samplesheet.csv'), emit: cleaned_dir_samplesheet
    path("versions.yml"),              emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-core/phylophoenix/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    if (params.ica==false) {
        ica = ""
    } else if (params.ica==true) {
        ica = "python ${workflow.launchDir}/bin/"
    } else {
        error "Please set params.ica to either \"true\" if running on ICA or \"false\" for all other methods."
    }
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    ${ica}remove_failures.py -s ${summary} -d ${directory_samplesheet}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}
