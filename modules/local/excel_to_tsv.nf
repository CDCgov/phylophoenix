process XLSX_TO_TSV {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    path(xlsx)

    output:
    path("*.tsv"),        emit: tsv_samplesheet
    path("versions.yml"), emit: versions

    script:
    // get container info
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    def prefix = "${xlsx}" - ".xlsx"
    """

    ${ica}excel_to_tsv.py ${xlsx} --output ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
