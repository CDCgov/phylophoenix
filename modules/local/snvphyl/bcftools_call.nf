/* Bcftools call  */
process BCFTOOLS_CALL {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/bcftools:1.15"

    input:
    tuple val(meta), path(mpileup_vcf_gz)

    output:
    tuple val(meta), path("${meta.id}_mpileup.bcf"), emit: mpileup_bcf
    path("versions.yml"),                            emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bcftools index -f ${mpileup_vcf_gz}
    bcftools call --ploidy 1 --threads 4 --output ${prefix}_mpileup.bcf --output-type b --consensus-caller ${mpileup_vcf_gz}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """
}