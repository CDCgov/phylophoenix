/* Freebayes variant calling */
process FREEBAYES {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/freebayes:1.3.6"

    input:
    tuple val(meta), path(sorted_bams),
    path(ref_fai), path(ref_sma), path(ref_smi), 
    path(ref_genome)

    output:
    tuple val(meta), path( "${meta.id}_freebayes.vcf" ), emit: vcf_files
    path("versions.yml"),                                emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """

    freebayes --bam ${sorted_bams} --ploidy 1 --fasta-reference ${ref_genome} --vcf ${prefix}_freebayes.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        freebayes: \$(echo \$(freebayes --version 2>&1) | sed 's/version:\s*v//g' )
    END_VERSIONS
    """
}