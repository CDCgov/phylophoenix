/* in the case of a given directory we can get reads from that easy. If a samplesheet is given then the directory is there. */
process CONVERT_INPUT {
    tag "${meta.seq_type}"
    label 'process_low'
    container params.phoenix_base_container

    input:
    tuple val(meta), path(sample_sheet)
    //path(directory)

    output:
    path("updated_samplesheet.csv"), emit: updated_samplesheet
    path("versions.yml"),            emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    // get container info
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def samplesheet = sample_sheet ? "--samplesheet ${sample_sheet}" : ""
    """
    ${ica}convert_samplesheet.py ${samplesheet} -t ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}