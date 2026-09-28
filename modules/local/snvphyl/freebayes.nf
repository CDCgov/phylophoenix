/* Freebayes variant calling */
process FREEBAYES {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_low'
    //1.3.10
    container "staphb/freebayes@sha256:c97654c8bdc2f2f30ebdfff8507826bf8f58af18bbcd58d8c74dd77b76a2687d"

    input:
    tuple val(meta), path(sorted_bams),
    path(ref_fai), path(ref_sma), path(ref_smi), 
    path(ref_genome)

    output:
    tuple val(meta), path( "${meta.id}_freebayes.vcf" ), emit: vcf_files
    path("versions.yml"),                                emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "staphb/freebayes@"
    //set up for terra
    if (params.terra==false) {
        terra = ""
        terra_exit = ""
    } else {
        terra = "PATH=/opt/conda/envs/freebayes/bin:\$PATH"
        terra_exit = """PATH="\$(printf '%s\\n' "\$PATH" | sed 's|/opt/conda/envs/freebayes/bin:||')" """
    }
    """
    #adding python path for running freebayes on terra
    $terra

    freebayes --bam ${sorted_bams} --ploidy 1 --fasta-reference ${ref_genome} --vcf ${prefix}_freebayes.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        freebayes: \$(echo \$(freebayes --version 2>&1) | sed 's/version:\s*v//g' )
        freebayes_container: ${container}
    END_VERSIONS

    #revert python path back to main envs for running on terra
    $terra_exit
    """
}