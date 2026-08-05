process ASSET_CHECK {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:3a6b2b34adb0983c4a022412969b497b660d3bad1123135189e8c831f172bce7'

    input:
    tuple val(meta), path(zipped_fasta)

    output:
    tuple val(meta), path("$gunzip"), emit: unzipped_fasta
    path("versions.yml"),             emit: versions

    script:
    gunzip = zipped_fasta.toString() - '.gz'
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    if [[ ${zipped_fasta} == *.gz ]]
    then
        gunzip --force ${zipped_fasta}
    else
        :
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
