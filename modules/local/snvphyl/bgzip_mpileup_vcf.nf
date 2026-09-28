/* Zip mpileup vcf*/
process BGZIP_MPILEUP_VCF {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    //1.23
    container "staphb/htslib@sha256:de457f8988e2c6e136875511110648087546aace377022a6f784c028de7e3b3a"

    input:
    tuple val(meta), path(mpileup_vcf)

    output:
    tuple val(meta), path("${meta.id}_mpileup.vcf.gz"), emit: mpileup_zipped
    path("versions.yml"),                               emit: versions

    script:
    def container = task.container.toString() - "staphb/htslib@"
    """
    bgzip -f ${mpileup_vcf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bgzip (htslib): \$( bgzip --version | head --lines 1 | sed 's/bgzip (htslib) //' )
        htslib_container: ${container}
    END_VERSIONS
    """
}