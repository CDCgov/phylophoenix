process CREATE_SAMPLESHEET {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v1.1.0'

    input:
    path(directory) // -s

    output:
    path("Directory_samplesheet.csv"), emit: samplesheet
    path("versions.yml"),              emit: versions

    script: // This script is bundled with the pipeline, in cdcgov/griphin/bin/
    """
    full_path=\$(readlink -f ${directory}/Phoenix_Summary.tsv )
    full_dir=\$(echo \$full_path | sed 's/\\/Phoenix_Summary.tsv//')
    create_samplesheet.py --directory \$full_dir

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}