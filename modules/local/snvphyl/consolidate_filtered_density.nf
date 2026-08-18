/* CONSOLIDATED_ALL */
process CONSOLIDATE_FILTERED_DENSITY {
    tag "${meta.seq_type}"
    label 'process_low'
    container params.phoenix_base_container

    input:
    tuple val(meta), path(filtered_densities), path(invalid_positions)

    output:
    tuple val(meta), path("${meta.seq_type}_filtered_density_all.txt"),  emit: filtered_densities
    tuple val(meta), path("${meta.seq_type}_new_invalid_positions.bed"), emit: new_invalid_positions
    path("versions.yml"),                                                emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    find ./ -name '*_filtered_density.txt' -exec cat {} + > ${meta.seq_type}_filtered_density_all.txt
    ${ica}catWrapper.py ${meta.seq_type}_new_invalid_positions.bed ${meta.seq_type}_filtered_density_all.txt ${invalid_positions}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container: ${container}
        phoenix_base_version: ${container_version}
    END_VERSIONS
    """
}