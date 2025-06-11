/* Zip mpileup vcf*/
process BGZIP_MPILEUP_VCF {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/htslib:1.15"

    input:
    tuple val(meta), path(mpileup_vcf)

    output:
    tuple val(meta), path("${meta.id}_mpileup.vcf.gz"), emit: mpileup_zipped
    path("versions.yml"),                               emit: versions

    script:
    """
    bgzip -f ${mpileup_vcf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bgzip (htslib): \$( bgzip --version | head --lines 1 | sed 's/bgzip (htslib) //' )
    END_VERSIONS
    """
}