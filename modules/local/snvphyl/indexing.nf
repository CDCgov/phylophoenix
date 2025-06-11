process INDEXING {
    tag "${meta.seq_type}"
    label 'process_low'
    container "staphb/smalt:0.7.6"

    input:
    tuple val(meta), path(refgenome)

    output:
    tuple val(meta), path('*.fai'), path('*.sma'), path('*.smi'), emit: ref_indexes
    path("versions.yml"),                                         emit: versions

    script:
    """
    REF_BASENAME=\$(basename ${refgenome} .fasta)
    smalt index -k 13 -s 6 \${REF_BASENAME} ${refgenome}
    samtools faidx ${refgenome}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smalt: \$( smalt version | grep "Version:" | sed 's/Version://' )
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}