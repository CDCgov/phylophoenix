process GET_CENTROID {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    tuple val(meta), path(mash_distance), \
    path(griphin_samplesheet) // -s

    output:
    tuple val(meta), path("path_to_${meta.seq_type}_centroid.csv"), emit: centroid_path
    tuple val(meta), path("${meta.seq_type}_centroid_info.txt"),    emit: centroid_info
    path("versions.yml"),                                           emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    # combine all lists
    for f in *.txt; do cat "\$f" >> ${meta.seq_type}_dists.tsv; done

    ${ica}get_centroid.py -i ${meta.seq_type}_dists.tsv -s ${griphin_samplesheet} -t ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}