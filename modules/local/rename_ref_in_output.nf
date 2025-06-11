process RENAME_REF_IN_OUTPUT {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    tuple val(meta), path(centroid_file), path(tree_file), path(snvmatrix), path(metadata_file)

    output:
    path("${meta.seq_type}_snvMatrix.tsv"),                       emit: snvMatrix
    path("${meta.seq_type}_SNVPhyl.newick"),       optional:true, emit: phylogeneticTree
    path("${meta.seq_type}_cleaned_metadata.tsv"), optional:true, emit: cleaned_metadata
    path("versions.yml"),                                         emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    if (params.ica==false) {
        ica = ""
    } else if (params.ica==true) {
        ica = "python ${workflow.launchDir}/bin/"
    } else {
        error "Please set params.ica to either \"true\" if running on ICA or \"false\" for all other methods."
    }
    // get container info
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    // define variables
    def metadata = metadata_file ? "-m ${metadata_file}" : ""
    def tree  = tree_file ? "-n ${tree_file}" : ""
    """
    ${ica}rename_reference.py ${tree} -s ${snvmatrix} -c ${centroid_file} -o ${meta.seq_type} ${metadata}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}