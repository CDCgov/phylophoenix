process ASSET_PREP {
    tag "${meta.seq_type}"
    label 'process_low'
    stageInMode 'copy'
    container 'quay.io/jvhagey/phoenix:base_v2.1.0'

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
    if (params.ica==false) {
        ica = ""
    } else if (params.ica==true) {
        ica = "python ${workflow.launchDir}/bin/"
    } else {
        error "Please set params.ica to either \"true\" if running on ICA or \"false\" for all other methods."
    }
    refname = zipped_fasta.toString() - '.filtered.scaffolds.fa.gz'
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
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
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}
