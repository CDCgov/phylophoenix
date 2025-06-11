/* Filtered freebayes vcf to bcf */
process FREEBAYES_VCF_TO_BCF {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/bcftools:1.15"

    input:
    tuple val(meta), path(freebayes_filtered_vcf_gz)

    output:
    tuple val(meta), path( "${meta.id}_freebayes_filtered.bcf" ), path( "${meta.id}_freebayes_filtered.bcf.csi" ), emit: filtered_bcf
    path("versions.yml"),                                                                                            emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bcftools index -f ${freebayes_filtered_vcf_gz}
    bcftools view --output-type b --output-file ${prefix}_freebayes_filtered.bcf ${freebayes_filtered_vcf_gz}
    bcftools index -f ${prefix}_freebayes_filtered.bcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """
}