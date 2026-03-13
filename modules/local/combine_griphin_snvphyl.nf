process COMBINE_GRIPHIN_SNVPHYL {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    path(snvMatrix)
    path(vcf2core)
    path(griphin_report)
    path(blind_list)
    val(window_size)

    output:
    path("SNVPhyl_GRiPHin_Summary.xlsx"), emit: updated_samplesheet
    path("versions.yml"),                 emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def blind_names = blind_list ? "--blind_list ${blind_list}" : ""
    // get container info
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}combine_griphin_snvphyl.py -g ${griphin_report} --window_size ${window_size} ${blind_names}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}