process GET_COMPARISONS {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:3a6b2b34adb0983c4a022412969b497b660d3bad1123135189e8c831f172bce7'

    input:
    path(griphin_samplesheet) // -s
    path(griphin) // -g
    val(combine_complexes)

    output:
    path("All_*_Isolates_samplesheet.csv"),             emit: samplesheet     // headers: id,seq_type,assembly_1,assembly_2
    path("SNVPhyl_All_*_Isolates_samplesheet_pre.csv"), emit: snv_samplesheet // headers: id,directory
    path("versions.yml"),                               emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def combine_complexes_arg = combine_complexes ? "--combine_complex" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}create_comparisions.py -s ${griphin_samplesheet} -g ${griphin} ${combine_complexes_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}