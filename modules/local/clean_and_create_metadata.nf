process CLEAN_AND_CREATE_METADATA {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

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
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}clean_and_create_metadata.py -i ${metadata} -o ${meta.seq_type}_prerename_metadata.tsv -g ${griphin_report} --bldb ${bldb}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}