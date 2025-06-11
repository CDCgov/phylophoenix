process ASSET_CHECK {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    tuple val(meta), path(zipped_fasta)

    output:
    tuple val(meta), path("$gunzip"), emit: unzipped_fasta
    path("versions.yml"),             emit: versions

    script:
    gunzip = zipped_fasta.toString() - '.gz'
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
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
