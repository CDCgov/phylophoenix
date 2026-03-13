process GRIPHIN {
    // base_v2.2.0 - MUST manually change below (line 36)!!!
    container 'quay.io/jvhagey/phoenix@sha256:ba44273acc600b36348b96e76f71fbbdb9557bb12ce9b8b37787c3ef2b7d622f'

    input:
    path(db)
    path(original_samplesheet)
    val(metas)
    path(griphin_files) // path to the GRiPHin files, which includes the staged directory
    path(outdir) //output directory used as prefix for the summary file
    val(phx_version)
    val(coverage)
    val(phx_mode)
    val(shigapass_detected)
    val(centar_detected)
    path(bldb)
    val(filter_var) // needed for species specific mode
    val(dont_publish)
    path(blind_list) // -b (mostly needed for PhyloPHoenix runs)
    val(old_phx_version)  // ADD THIS - version string instead of file


    output:
    tuple path("full_path_file.txt"), path("*_GRiPHin*.xlsx"),                         emit: griphin_report
    tuple path("full_path_file.txt"), path("*_GRiPHin*.xlsx"), path("*_GRiPHin*.tsv"), emit: griphins
    path("*_GRiPHin*.tsv"),                                                            emit: griphin_tsv_report
    path("*_GRiPHin*.xlsx"),                                                           emit: griphin_excel_report
    path("Directory_samplesheet.csv"), optional:true,                                  emit: converted_samplesheet //the only time this isn't made is with --centar with --samplesheet
    path("versions.yml"),                                                              emit: versions

    script: // This script is bundled with the pipeline, in cdcgov/griphin/bin/
    // Adding if/else for if running on ICA it is a requirement to state where the script is, however, this causes CLI users to not run the pipeline from any directory.
    def ica = params.ica ? "python ${params.bin_dir}" : ""
    // define variables
    def old_software_arg
    if (old_phx_version && old_phx_version != "" && old_phx_version != "null") {
        if (params.mode_upper != "PHYLOPHOENIX") {
            old_software_arg = "--old_software_version ${old_phx_version}"
        } else {
            old_software_arg = "--old_software_version PHX_${old_phx_version}"
        }
    } else {
        old_software_arg = ""
    }
    def current_version = (params.mode_upper == "PHYLOPHOENIX") ? "PhyloPHX_${phx_version}" : "${phx_version}" 
    def blind_names = blind_list ? "--blind_list ${blind_list}" : ""
    def phoenix_mode = phx_mode ? "" : "--phoenix"
    def scaffolds = (params.mode_upper == "SCAFFOLDS" || params.mode_upper == "CDC_SCAFFOLDS") ? "--scaffolds" : "" 
    def shigapass = shigapass_detected ? "--shigapass" : ""
    def centar = centar_detected ? "--centar" : ""
    def updater = (params.mode_upper == "UPDATE_PHOENIX") ? "--updater" : "" 
    def pass_dir = (params.mode_upper == "PHYLOPHOENIX") ? "" : "-d \$full_path" 
    //def samplesheet_command = (centar_detected && original_samplesheet) ? "--samplesheet ${original_samplesheet}" : ""
    def filter = filter_var ? "--filter_samples" : ""
    def output_prefix = ((dont_publish == true) || (params.mode_upper == "CENTAR" && params.indir == null)) ? "${outdir}_GRiPHin" : "${outdir}_GRiPHin_Summary" 
    def container_version = "base_v2.2.0"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    def prefix = task.ext.prefix ?: "GRiPHin"
    def stage_files = [
        metas.collect { "mkdir -p ${prefix}/${it.id}" },
        metas.collect { "mv ${it.filenames.join(' ')} ${prefix}/${it.id}" }
    ].flatten().join(" && ")
    """
    ${stage_files}

    # Get full path to outdir for parent folder and data location columns in griphin
    full_path=\$(readlink -f ${outdir})

    # Save the full_path to a file (this file will be captured in the output block)
    echo \$full_path > full_path_file.txt

    # rename input samplesheet so it gets passed along.
    if [[ ${original_samplesheet} != "Directory_samplesheet.csv" ]]; then
        mv ${original_samplesheet} Directory_samplesheet.csv
    fi

    ${ica}GRiPHin.py ${pass_dir} --ar_db ${db} --output ${output_prefix} --bldb ${bldb} --phx_version ${current_version} ${filter}\
        --coverage ${coverage} ${phoenix_mode} ${shigapass} ${centar} ${scaffolds} --samplesheet Directory_samplesheet.csv ${updater} ${blind_names} ${old_software_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        griphin.py: \$(${ica}GRiPHin.py --version)
        bldb_creation_date: \$(echo ${bldb} | sed 's/[^0-9]//g')
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}