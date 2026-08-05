/* Verifying Mapping Quality */
process VERIFYING_MAP_Q {
    tag "${meta.seq_type}"
    label 'process_medium'
    container "staphb/snvphyl-tools@sha256:a81b1df43b98dc4ad18f4bfe9b36f83a26f27cc3560c1e1a1004cc20bb3d0c68"

    input:
    tuple val(meta), path(sorted_bams)
    val(bam_line)

    output:
    path("mappingQuality.txt"), emit: mapping_quality
    path("versions.yml"),       emit: versions

    script:
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
    # set up for terra
    $terra

    verify_mapping_quality.pl -c 4 --min-depth 10 --min-map 80 --output mappingQuality.txt ${bam_line}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snvphyl-tools_version: \$(sed -n '3{s/^## //p}' ../../snvphyl-tools-*/CHANGELOG.md)
        snvphyl-tools_container: ${container}
        perl: \$(perl --version | grep "This is perl" | sed 's/.*(\\(.*\\))/\\1/' | cut -d " " -f1)
    END_VERSIONS

    # revert back to original env for terra
    $terra_exit
    """
}