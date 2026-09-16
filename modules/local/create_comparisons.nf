process GET_COMPARISONS {
    label 'process_low'
    container params.phoenix_base_container

    input:
    path(griphin_samplesheet) // -s
    path(griphin) // -g
    val(combine_complexes)
    val(by_all)
    val(no_species)
    //path(ref_genome)

    output:
    path("All_*Isolates_samplesheet.csv"),             emit: samplesheet     // headers: id,seq_type,assembly_1,assembly_2
    path("SNVPhyl_All_*Isolates_samplesheet_pre.csv"), emit: snv_samplesheet // headers: id,directory
    path("versions.yml"),                              emit: versions

    script: // This script is bundled with the pipeline, in dhqp/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def combine_complexes_arg = combine_complexes ? "--combine_complex" : ""
    def by_all_arg = by_all ? "--by_all" : ""
    def no_species_arg = no_species ? "--no_species" : ""
    //def ref_genome_arg = ref_genome ? "--ref_genome ${ref_genome}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    ${ica}create_comparisions.py -s ${griphin_samplesheet} -g ${griphin} ${combine_complexes_arg} ${by_all_arg} ${no_species_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}