/* Consolidate bcfs */
process CONSOLIDATE_BCFS {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_medium'
    container "staphb/snvphyl-tools:1.8.2"

    input:
    tuple val(meta), path(mpileup_bcf), path(freebayes_filtered_bcf), path(freebayes_filtered_csi)

    output:
    tuple val(meta), path( "${meta.id}_consolidated.bcf" ),     emit: consolidated_bcfs
    tuple val(meta), path( "${meta.id}_consolidated.vcf" ),     emit: consolidated_vcfs
    tuple val(meta), path( "${meta.id}_consolidated.bcf.csi" ), emit: consolidated_bcf_index
    tuple val(meta), path( "${meta.id}_filtered_density.txt" ), emit: filtered_densities
    path("versions.yml"),                                       emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "staphb/snvphyl-tools:"
    """
    consolidate_vcfs.pl --coverage-cutoff 10 --min-mean-mapping 30 --snv-abundance-ratio 0.75 --vcfsplit ${freebayes_filtered_bcf} --mpileup ${mpileup_bcf} --filtered-density-out ${prefix}_filtered_density.txt --window-size ${params.window_size} --density-threshold ${params.density_threshold} -o ${prefix}_consolidated.bcf > ${prefix}_consolidated.vcf
    bcftools index -f ${prefix}_consolidated.bcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools: ${container}
        bcftools: \$( bcftools --version |& sed '1!d; s/^.*bcftools //' )
    END_VERSIONS
    """
}