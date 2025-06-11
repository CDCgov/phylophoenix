process GET_CENTROID {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    tuple val(meta), path(mash_distance), \
    path(griphin_samplesheet) // -s

    output:
    tuple val(meta), path("path_to_${meta.seq_type}_centroid.csv"), emit: centroid_path
    tuple val(meta), path("${meta.seq_type}_centroid_info.txt"),    emit: centroid_info
    path("versions.yml"),                                           emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    if (params.ica==false) {
        ica = ""
    } else if (params.ica==true) {
        ica = "python ${workflow.launchDir}/bin/"
    } else {
        error "Please set params.ica to either \"true\" if running on ICA or \"false\" for all other methods."
    }
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    # combine all lists
    cat *.txt > ${meta.seq_type}_dists.tsv

    ${ica}get_centroid.py -i ${meta.seq_type}_dists.tsv -s ${griphin_samplesheet} -t ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}