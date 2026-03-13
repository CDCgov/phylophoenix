/* Bcftools call  */
process BCFTOOLS_CALL {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    // 1.22
    container "staphb/bcftools@sha256:ed18acf5cf13613007e103dfea46778da408c8deac9c05b8e03f5741ac8d0a83"

    input:
    tuple val(meta), path(mpileup_vcf_gz)

    output:
    tuple val(meta), path("${meta.id}_mpileup.bcf"), emit: mpileup_bcf
    path("versions.yml"),                            emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "staphb/bcftools@"
    """
    bcftools index -f ${mpileup_vcf_gz}
    bcftools call --ploidy 1 --threads 4 --output ${prefix}_mpileup.bcf --output-type b --consensus-caller ${mpileup_vcf_gz}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
        bcftools_container: ${container}
    END_VERSIONS
    """
}