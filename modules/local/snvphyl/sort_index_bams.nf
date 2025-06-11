/* Create BAMs and Sort */
process SORT_INDEX_BAMS {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/samtools:1.9"

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path( "${meta.id}_sorted.bam" ), emit: sorted_bams
    path("versions.yml"),                             emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools sort -O bam -o ${prefix}_sorted.bam ${bams}
    samtools index ${prefix}_sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}