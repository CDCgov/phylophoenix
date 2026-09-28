process GET_CENTROID {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:3a6b2b34adb0983c4a022412969b497b660d3bad1123135189e8c831f172bce7'

    input:
    tuple val(meta), path(ref_genome), path(mash_distance), path(griphin_samplesheet)

    output:
    tuple val(meta), path("path_to_${meta.seq_type}_centroid.csv"), emit: centroid_path
    tuple val(meta), path("${meta.seq_type}_centroid_info.txt"),    emit: centroid_info
    path("versions.yml"),                                           emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def ref_genome_name = ref_genome.name.toString() - '.filtered.scaffolds.fa'
    def ref_genome_path = (params.ref_genome) ? ref_genome.toRealPath() : ""
    def passed_ref = (params.ref_genome) ? true : false
    """
    if [[ ${passed_ref} == true ]]
    then
        echo "${ref_genome_name} is set as the centroid for ${meta.seq_type}" > ${meta.seq_type}_centroid_info.txt
        echo "${ref_genome_path}" > path_to_${meta.seq_type}_centroid.csv
    else
        # combine all lists
        for f in *.txt; do cat "\$f" >> ${meta.seq_type}_dists.tsv; done

        ${ica}get_centroid.py -i ${meta.seq_type}_dists.tsv -s ${griphin_samplesheet} -t ${meta.seq_type}
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}