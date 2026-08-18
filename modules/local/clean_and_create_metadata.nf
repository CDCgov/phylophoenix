process CLEAN_AND_CREATE_METADATA {
    tag "${meta.seq_type}"
    label 'process_low'
    container params.phoenix_base_container

    input:
    tuple val(meta), path(metadata)
    path(griphin_report)
    path(geonames_files)
    path(bldb)

    output:
    tuple val(meta), path("${meta.seq_type}_prerename_metadata.tsv"), emit: updated_metadata
    path("versions.yml"),                                             emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    // get container info
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}clean_and_create_metadata.py -i ${metadata} -o ${meta.seq_type}_prerename_metadata.tsv -g ${griphin_report} --bldb ${bldb}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}