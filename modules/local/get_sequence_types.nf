process GET_SEQUENCE_TYPES {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    path(griphin_samplesheet) // -s
    path(griphin_report) // -g
    path(blind_list) // -b
    val(secondary_mlst)

    output:
    path("*ST*_samplesheet.csv"),             emit: st_samplesheets     // headers: id,seq_type,assembly_1,assembly_2
    path("SNVPhyl_*ST*_samplesheet_pre.csv"), emit: st_snv_samplesheets // headers: id,directory
    path("versions.yml"),                    emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    //get blind_names if it exists
    def blind_names   = blind_list ? "--blind_list ${blind_list}" : ""
    def use_secondary_mlst = secondary_mlst ? "--use_secondary_mlst" : ""
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}get_st_types.py -g ${griphin_report} -s ${griphin_samplesheet} ${blind_names} ${use_secondary_mlst}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}