/* CONSOLIDATED_ALL */
process CONSOLIDATE_FILTERED_DENSITY {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    tuple val(meta), path(filtered_densities), path(invalid_positions)

    output:
    tuple val(meta), path("${meta.seq_type}_filtered_density_all.txt"),  emit: filtered_densities
    tuple val(meta), path("${meta.seq_type}_new_invalid_positions.bed"), emit: new_invalid_positions
    path("versions.yml"),                                                emit: versions

    script:
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
    find ./ -name '*_filtered_density.txt' -exec cat {} + > ${meta.seq_type}_filtered_density_all.txt
    ${ica}catWrapper.py ${meta.seq_type}_new_invalid_positions.bed ${meta.seq_type}_filtered_density_all.txt ${invalid_positions}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}