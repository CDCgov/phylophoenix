/* Filter freebayes vcf */
process FILTER_FREEBAYES {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    container "staphb/snvphyl-tools:1.8.2"

    input:
    tuple val(meta), path(freebayes_vcf)

    output:
    tuple val(meta), path( "${meta.id}_freebayes_filtered.vcf" ), emit: filtered_vcf
    path("versions.yml"),                                         emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // get container info
    def container = task.container.toString() - "staphb/snvphyl-tools:"
    """
    filterVcf.pl --noindels ${freebayes_vcf} -o ${prefix}_freebayes_filtered.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS
    """
}