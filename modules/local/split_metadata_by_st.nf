process SPLIT_METADATA_BY_ST {
    tag "${meta.seq_type}"
    label 'process_low'
    container params.phoenix_base_container

    input:
    tuple val(meta), path(st_snv_samplesheets), path(metadata)

    output:
    tuple val(meta), path("${meta.seq_type}_metadata.tsv"), emit: split_metadata
    path("versions.yml"),                                   emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    // get container info
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}split_metadata_by_st.py -m ${metadata} -s ${st_snv_samplesheets} --seq_type ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}