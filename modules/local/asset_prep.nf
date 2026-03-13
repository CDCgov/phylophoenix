process ASSET_PREP {
    tag "${meta.seq_type}"
    label 'process_low'
    stageInMode 'copy'
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    tuple val(meta), path(zipped_fasta)
    path(geo_data)
    tuple val(meta), path(st_snv_samplesheets)

    output:
    tuple val(meta), path("*.filtered.scaffolds.fa"),   emit: unzipped_fasta
    path("*_geolocation.txt"),                          emit: unzipped_geodata
    tuple val(meta), path("SNVPhyl_*_samplesheet.csv"), emit: st_snv_samplesheets // headers: id,directory
    path("versions.yml"),                               emit: versions

    script:
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    refname = zipped_fasta.toString() - '.filtered.scaffolds.fa.gz'
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix@"
    """
    if [[ ${zipped_fasta} == *.gz ]]
    then
        gunzip --force ${zipped_fasta}
    else
        :
    fi

    for file in ${geo_data}; do
        if [[ \$file == *.txt.xz ]]; then
            xz -d "\$file"
        fi
    done

    ${ica}remove_reference.py -r ${refname} -s ${st_snv_samplesheets} -o ${meta.seq_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container_tag: ${container_version}
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
