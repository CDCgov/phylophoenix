/* in the case of a given directory we can get reads from that easy. If a samplesheet is given then the directory is there. */
process CONVERT_INPUT {
    tag "${meta.seq_type}"
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

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
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def samplesheet = sample_sheet ? "--samplesheet ${sample_sheet}" : ""
    """
    ${ica}convert_samplesheet.py ${samplesheet} -t ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}