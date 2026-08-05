/* Filter Stats */
process FILTER_STATS {
    tag "${meta.seq_type}"
    label 'process_low'
    container "staphb/snvphyl-tools@sha256:a81b1df43b98dc4ad18f4bfe9b36f83a26f27cc3560c1e1a1004cc20bb3d0c68"

    input:
    tuple val(meta), path(snvTable)

    output:
    tuple val(meta), path('filterStats.txt'), emit: filter_stats
    path("versions.yml"),                     emit: versions

    script:
    // get container info
    def container = task.container.toString() - "staphb/snvphyl-tools@"
    //set up for terra
    if (params.terra==false) {
        terra = ""
        terra_exit = ""
    } else (params.terra==true) {
        terra = "PATH=/opt/conda/envs/snvphyl-tools/bin:\$PATH"
        terra_exit = """PATH="\$(printf '%s\\n' "\$PATH" | sed 's|/opt/conda/envs/snvphyl-tools/bin:||')" """
    }
    """
    #adding python path for running snvphyl-tools on terra
    $terra

    filter-stats.pl -i ${snvTable} -a > filterStats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools_version: \$(sed -n '3{s/^## //p}' ../../snvphyl-tools-*/CHANGELOG.md)
        snvphyl-tools_container: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS

    #revert python path back to main envs for running on terra
    $terra_exit
    """
}