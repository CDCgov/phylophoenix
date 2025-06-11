/* PHYML to make tree */
process PHYML {
    tag "${meta.seq_type}"
    label 'process_low'
    container = "staphb/phyml:3.3.20220408"
    //container "https://depot.galaxyproject.org/singularity/phyml:3.3.20211231--hee9e358_0"

    input:
    tuple val(meta), path(snvAlignment_phy)

    output:
    tuple val(meta), path("pre_${meta.seq_type}_SNVPhyl.newick"),    emit: phylogeneticTree
    tuple val(meta), path("${meta.seq_type}_TreeStats_SNVPhyl.txt"), emit: phylogeneticTreeStats
    path("versions.yml"),                                            emit: versions

    script:
    """

    phyml -i ${snvAlignment_phy} --datatype nt --model GTR -v 0.0 -s BEST --ts/tv e --nclasses 4 --alpha e --bootstrap -4 --quiet
    mv ${meta.seq_type}_snvAlignment.phy_phyml_stats.txt ${meta.seq_type}_TreeStats_SNVPhyl.txt
    mv ${meta.seq_type}_snvAlignment.phy_phyml_tree.txt pre_${meta.seq_type}_SNVPhyl.newick

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        phyml: \$( phyml --version | grep -P -o '[0-9]+.[0-9]+.[0-9]+' )
    END_VERSIONS
    """
}