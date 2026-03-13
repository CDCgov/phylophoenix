/* Generate a line for the next process */
process GENERATE_LINE_2 {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    tuple val(meta), path(consolidated_bcf)

    output:
    tuple val(meta), path("consolidation_line.txt"), emit: consolidation_line
    path("versions.yml"),                            emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    // get container info
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}make_consolidation_line.sh

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}