process COMBINE_GRIPHIN_SNVPHYL {
    label 'process_low'
    container params.phoenix_base_container

    input:
    path(snvMatrix)
    path(vcf2core)
    path(griphin_report)
    path(snvAlignment)
    path(blind_list)
    val(window_size)
    val(combine_complexes)
    val(by_all)

    output:
    path("SNVPhyl_GRiPHin_Summary.xlsx"), emit: updated_samplesheet
    path("versions.yml"),                 emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def combine_complexes_arg = combine_complexes ? "--combine_complex" : ""
    def by_all_arg = by_all ? "--by_all" : ""
    def blind_names = blind_list ? "--blind_list ${blind_list}" : ""
    // get container info
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}combine_griphin_snvphyl.py -g ${griphin_report} --window_size ${window_size} ${blind_names} ${combine_complexes_arg} ${by_all_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}