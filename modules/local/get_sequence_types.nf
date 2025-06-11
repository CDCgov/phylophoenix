process GET_SEQUENCE_TYPES {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    path(griphin_samplesheet) // -s
    path(griphin_report) // -g

    output:
    path("ST*_samplesheet.csv"),             emit: st_samplesheets     // headers: id,seq_type,assembly_1,assembly_2
    path("SNVPhyl_ST*_samplesheet_pre.csv"), emit: st_snv_samplesheets // headers: id,directory
    path("versions.yml"),                    emit: versions

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
    ${ica}get_st_types.py -g ${griphin_report} -s ${griphin_samplesheet}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}