/* Generate a line for the next process */
process GENERATE_LINE_2 {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    tuple val(meta), path(consolidated_bcf)

    output:
    tuple val(meta), path("consolidation_line.txt"), emit: consolidation_line
    path("versions.yml"),                            emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    if (params.ica==false) {
        ica = ""
    } else if (params.ica==true) {
        ica = "python ${workflow.launchDir}/bin/"
    } else {
        error "Please set params.ica to either \"true\" if running on ICA or \"false\" for all other methods."
    }
    // get container info
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    ${ica}make_consolidation_line.sh

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}