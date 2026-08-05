process INDEXING {
    tag "${meta.seq_type}"
    label 'process_low'
    container "staphb/smalt@sha256:3ad1e2913f85f86fc4b3b4636404b9188ea84b36ba967535042a7a2500906434"

    input:
    tuple val(meta), path(refgenome)

    output:
    tuple val(meta), path('*.fai'), path('*.sma'), path('*.smi'), emit: ref_indexes
    path("versions.yml"),                                         emit: versions

    script:
    def container = task.container.toString() - "staphb/smalt@"
    //set up for terra
    if (params.terra==false) {
        terra = ""
        terra_exit = ""
    } else (params.terra==true) {
        terra = "PATH=/opt/conda/envs/smalt/bin:\$PATH"
        terra_exit = """PATH="\$(printf '%s\\n' "\$PATH" | sed 's|/opt/conda/envs/smalt/bin:||')" """
    }
    """
    #adding python path for running smalt on terra
    $terra

    REF_BASENAME=\$(basename ${refgenome} .fasta)
    smalt index -k 13 -s 6 \${REF_BASENAME} ${refgenome}
    samtools faidx ${refgenome}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smalt: \$( smalt version | grep "Version:" | sed 's/Version://' )
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        smalt_container: ${container}
    END_VERSIONS

    #revert python path back to main envs for running on terra
    $terra_exit
    """
}