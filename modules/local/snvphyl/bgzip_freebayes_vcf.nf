/* Zip freebayes vcf*/
process BGZIP_FREEBAYES_VCF {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/htslib:1.15"

    input:
    tuple val(meta), path(freebayes_filtered_vcf)

    output:
    tuple val(meta), path("${meta.id}_freebayes_filtered.vcf.gz"), emit: filtered_zipped_vcf
    path("versions.yml"),                                          emit: versions

    script:
    """
    bgzip -f ${freebayes_filtered_vcf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bgzip (htslib): \$( bgzip --version | head --lines 1 | sed 's/bgzip (htslib) //' )
    END_VERSIONS
    """
}