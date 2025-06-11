/* VCF2SNV_ALIGNMENT Call variants */
process VCF2SNV_ALIGNMENT {
    tag "${meta.seq_type}"
    label 'process_medium'
    container "staphb/snvphyl-tools:1.8.2"

    input:
    tuple val(meta), val(consolidate_bcfs)
    tuple val(meta), path(bcf)
    tuple val(meta), path(new_invalid_positions)
    tuple val(meta), path(refgenome)
    tuple val(meta), path(consolidated_bcf_index)

    output:
    tuple val(meta), path("${meta.seq_type}_snvAlignment.phy"), emit: snvAlignment
    tuple val(meta), path("${meta.seq_type}_vcf2core.tsv"),     emit: vcf2core
    tuple val(meta), path("${meta.seq_type}_snvTable.tsv"),     emit: snvTable
    tuple val(meta), path("${meta.seq_type}_emptyMatrix.tsv"),  emit: emptyMatrix
    path("versions.yml"),                                       emit: versions

    script:
    def container = task.container.toString() - "staphb/snvphyl-tools:"
    """
    vcf2snv_alignment.pl --reference reference --invalid-pos ${new_invalid_positions} --format fasta --format phylip --numcpus 4 --output-base snvalign --fasta ${refgenome} ${consolidate_bcfs} 
    mv snvalign-positions.tsv ${meta.seq_type}_snvTable.tsv
    mv snvalign-stats.csv ${meta.seq_type}_vcf2core.tsv

    # if the tree file was created, rename it to the expected name
    if [[ -f snvalign.phy ]]; then
        mv snvalign.phy ${meta.seq_type}_snvAlignment.phy
        sed -i "s/'//" ${meta.seq_type}_snvAlignment.phy
        sed -i "s/'//" ${meta.seq_type}_snvAlignment.phy
        touch ${meta.seq_type}_emptyMatrix.tsv # just make a blank file to keep things moving as its needed for make_snv process
    elif grep -q "No valid positions were found. Not creating empty alignment file" .command.out; then
        # no snv differences found collecting some information to make empty snv matrix
        echo "No valid positions were found. Creating empty snvMatrix to pass to next process for clean up." > ${meta.seq_type}_snvAlignment.phy
        files=()
        files+=("strain")
        for file in *_consolidated.bcf; do
            files+=("\$(basename "\$file" _consolidated.bcf)")
        done
        files+=("reference")
        printf "%s\t" "\${files[@]}" | paste -sd "\t" - > ${meta.seq_type}_emptyMatrix.tsv
        # Write subsequent lines until `files` is exhausted
        for ((i=1; i < \${#files[@]}; i++)); do
            # Prepare the line: first element followed by 0s for the remaining elements
            zeros=\$(printf "0\t%.0s" \$(seq 1 \$((\${#files[@]} - 1))))
            # Write the current element followed by the zeros to the file
            echo -e "\${files[\$i]}\t\$zeros" >> ${meta.seq_type}_emptyMatrix.tsv
        done
        touch ${meta.seq_type}_snvAlignment.phy
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS
    """
}