/* Map reads to reference genome & create BAM file */
process SMALT_MAP {
    tag "${meta.id}_${meta.seq_type}"
    label 'process_medium'
    container "staphb/smalt@sha256:3ad1e2913f85f86fc4b3b4636404b9188ea84b36ba967535042a7a2500906434"

    input:
    tuple val(meta), path(reads), path(ref_fai), path(ref_sma), path(ref_smi)
    //tuple val(meta_2), path(ref_fai), path(ref_sma), path(ref_smi)

    output:
    tuple val(meta), path("${meta.id}.bam"), emit: bams
    path("versions.yml"),                    emit: versions

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def ref_name = ref_fai.toString() - '.fai'
    def container = task.container.toString() - "staphb/smalt@"
    //set up for terra
    if (params.terra==false) {
        terra = ""
        terra_exit = ""
    } else {
        terra = "PATH=/opt/conda/envs/smalt/bin:\$PATH"
        terra_exit = """PATH="\$(printf '%s\\n' "\$PATH" | sed 's|/opt/conda/envs/smalt/bin:||')" """
    }
    """
    #adding python path for running smalt on terra
    $terra

    smalt map -f bam -n 4 -l pe -i 1000 -j 20 -r -1 -y 0.5 -o ${prefix}.bam ${ref_name} ${reads[0]} ${reads[1]}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smalt: \$( smalt version | grep "Version:" | sed 's/Version://' )
        smalt_container: ${container}
    END_VERSIONS

    # revert python path back to main envs for running on terra
    $terra_exit
    """
}
