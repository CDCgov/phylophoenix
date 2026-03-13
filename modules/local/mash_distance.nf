process MASH_DIST {
    tag "${meta.id}"
    label 'process_low'
    container "staphb/mash@sha256:d55d03b75eb3a88bf0e93253487580f828f6a25b324a7c28fb8e4eaca0d5eebf"

    input:
    tuple val(meta), path(reference), path(query)

    output:
    tuple val(meta), path("*.txt"), emit: dist
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "staphb/mash@"
    """
    mash \\
        dist \\
        -p $task.cpus \\
        $args \\
        $reference \\
        $query > ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mash: \$(mash --version 2>&1)
        mash_container: ${container}
    END_VERSIONS
    """
}
