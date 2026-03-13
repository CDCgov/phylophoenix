process ASSET_CHECK {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    tuple val(meta), path(zipped_fasta)

    output:
    tuple val(meta), path("$gunzip"), emit: unzipped_fasta
    path("versions.yml"),             emit: versions

    script:
    gunzip = zipped_fasta.toString() - '.gz'
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    if [[ ${zipped_fasta} == *.gz ]]
    then
        gunzip --force ${zipped_fasta}
    else
        :
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
