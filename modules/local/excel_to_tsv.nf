process XLSX_TO_TSV {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:3a6b2b34adb0983c4a022412969b497b660d3bad1123135189e8c831f172bce7'

    input:
    path(xlsx)

    output:
    path("*.tsv"),        emit: tsv_samplesheet
    path("versions.yml"), emit: versions

    script:
    // get container info
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = params.phoenix_container_version
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def prefix = "${xlsx}" - ".xlsx"
    """

    ${ica}excel_to_tsv.py ${xlsx} --output ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_version: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
