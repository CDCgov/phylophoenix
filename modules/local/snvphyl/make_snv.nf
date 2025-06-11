/* Making SNV matrix */
process MAKE_SNV {
    tag "${meta.seq_type}"
    label 'process_low'
    container "staphb/snvphyl-tools:1.8.2"

    input:
    tuple val(meta), path(snvAlignment_phy), path(emptyMatrix)

    output:
    tuple val(meta), path("snvMatrix_pre_${meta.seq_type}.tsv"), emit: snvMatrix
    path("versions.yml"),                                        emit: versions

    script:
    def container = task.container.toString() - "staphb/snvphyl-tools:"
    """
    # check if the tree was made and if not rename the empty matrix so to pass it downstream otherwise make a normal snvmatrix
    if grep -q "No valid positions were found." ${snvAlignment_phy}; then
        mv ${emptyMatrix} snvMatrix_pre_${meta.seq_type}.tsv
    else
        snv_matrix.pl ${snvAlignment_phy} -o snvMatrix_pre_${meta.seq_type}.tsv
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS
    """
}