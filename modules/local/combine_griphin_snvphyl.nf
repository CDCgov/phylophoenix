process COMBINE_GRIPHIN_SNVPHYL {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

    input:
    path(snvMatrix)
    path(vcf2core)
    path(griphin_report)

    output:
    path("SNVPhyl_GRiPHin_Summary.xlsx"), emit: updated_samplesheet
    path("versions.yml"),                 emit: versions

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
    """
    ${ica}combine_griphin_snvphyl.py -g ${griphin_report}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}