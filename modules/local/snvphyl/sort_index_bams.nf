/* Create BAMs and Sort */
process SORT_INDEX_BAMS {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/samtools@sha256:fbf9f15b45f9109c23345ece8ca18d8a7412e954c539f6af29566115bd2d3fc1"

    input:
    tuple val(meta), path(bams)

    output:
    tuple val(meta), path( "${meta.id}_sorted.bam" ), emit: sorted_bams
    path("versions.yml"),                             emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "staphb/samtools@"
    //set up for terra
    if (params.terra==false) {
        terra = ""
        terra_exit = ""
    } else (params.terra==true) {
        terra = "PATH=/opt/conda/envs/samtools/bin:\$PATH"
        terra_exit = """PATH="\$(printf '%s\\n' "\$PATH" | sed 's|/opt/conda/envs/samtools/bin:||')" """
    }
    """
    # set up for terra
    $terra

    samtools sort -O bam -o ${prefix}_sorted.bam ${bams}
    samtools index ${prefix}_sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        samtools_container: ${container}
    END_VERSIONS

    # revert back to original env for terra
    $terra_exit
    """
}