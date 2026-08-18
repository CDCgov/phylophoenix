process CREATE_SAMPLESHEET {
    label 'process_low'
    container params.phoenix_base_container

    input:
    path(directory) // -s

    output:
    path("Directory_samplesheet.csv"), emit: samplesheet
    path("versions.yml"),              emit: versions

    script: // This script is bundled with the pipeline, in cdcgov/griphin/bin/
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    full_path=\$(readlink -f ${directory}/Phoenix_Summary.tsv )
    full_dir=\$(echo \$full_path | sed 's/\\/Phoenix_Summary.tsv//')
    ${ica}create_samplesheet.py --directory \$full_dir

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}