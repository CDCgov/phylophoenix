process REMOVE_FAILURES {
    tag "$summary"
    label 'process_single'
    container 'quay.io/jvhagey/phoenix@sha256:3a6b2b34adb0983c4a022412969b497b660d3bad1123135189e8c831f172bce7'

    input:
    path(summary)
    path(directory_samplesheet)
    val(by_st_param)
    val(secondary_mlst_param)
    val(combine_complex_param)

    output:
    path('failed_ids.txt'),                 emit: failured_ids
    path('Directory_samplesheet_pass.csv'), emit: cleaned_dir_samplesheet
    path('redundant_taxa.txt'),             emit: redundant_taxa_file
    path('insufficient_samples.txt'),       emit: insufficient_samples_file
    path('by_st_eligible.txt'),             emit: by_st_eligible_file
    path('run_information.txt'),            emit: run_information_file
    path("versions.yml"),                   emit: versions

    script: // This script is bundled with the pipeline, in nf-core/phylophoenix/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def by_st = by_st_param ? "--by_st" : ""
    def secondary_mlst = secondary_mlst_param ? "--secondary_mlst" : ""
    def combine_complex = combine_complex_param ? "--combine_complex" : ""
    """
    ${ica}remove_failures.py -s ${summary} -d ${directory_samplesheet} ${by_st} ${secondary_mlst} ${combine_complex}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
