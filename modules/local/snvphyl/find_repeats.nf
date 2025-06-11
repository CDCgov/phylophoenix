/* Find repeats and create invaild_positions.bed */
process FIND_REPEATS {
    tag "${meta.seq_type}"
    label 'process_low'
    container "staphb/snvphyl-tools:1.8.2"

    input:
    tuple val(meta), path(refgenome)

    output:
    tuple val(meta), path("${meta.seq_type}_invalid_positions.bed"), emit: repeats_bed_file
    path("versions.yml"),                                            emit: versions

    script:
    // get container info
    def container = task.container.toString() - "staphb/snvphyl-tools:"
    """
    find-repeats.pl ${refgenome} --min-length 150 --min-pid 90 > ${meta.seq_type}_invalid_positions.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS
    """
}