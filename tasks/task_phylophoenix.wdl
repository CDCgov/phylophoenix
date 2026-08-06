version 1.0

task phylophoenix {
  input {
    Array[File] current_full_results
    String?     output_folder_name = "phylophx_output"
    Boolean?    no_all = false
    Boolean?    by_st = false
    File?       blind_list
    Boolean?    use_secondary_mlst = false
    Boolean?    combine_complex = false
    Int?        window_size = 500
    Int         memory = 64
    Int         cpu = 8
    Int         disk_size = 100
  }
  command <<<
    date | tee DATE
    version="dev" 
    echo $version | tee VERSION

    # Debug
    export TMP_DIR=$TMPDIR
    export TMP=$TMPDIR
    env

    # Start the samples_directory.csv with just the header
    echo "sample,directory" > samples_directory.csv

    # Loop over every tarball in the array
    for tarball in ~{sep=' ' current_full_results}; do
      samplename=$(basename "${tarball}" .tar.gz)
      samplename="${samplename%_updated}" #remove the "_updated" suffix if present
      # Untar data to update
      mkdir -p "./full_results"
      tar -xzf "${tarball}" -C "./full_results"
      project_directory="/mnt/disks/cromwell_root/full_results/${samplename}/phx_output/${samplename}"
      # Append this sample's line to the shared samples_directory.csv
      echo "${samplename},${project_directory}" >> samples_directory.csv
    done

    #set input variable
    input_file="--input ../samples_directory.csv"

    mkdir phylophx_run
    cd phylophx_run

    if nextflow run cdcgov/phylophoenix -plugins nf-google@1.1.3 -profile terra -r $version --outdir ./~{output_folder_name} --terra $input_file ~{if defined(blind_list) then "--blind_list " + blind_list else ""} \
        ~{true='--by_st' false='' by_st} ~{true='--no_all' false='' no_all} ~{true='--combine_complex' false='' combine_complex} ~{true='--use_secondary_mlst' false='' use_secondary_mlst} \
        --window_size ~{window_size} --tmpdir $TMPDIR --max_cpus ~{cpu} --max_memory '~{memory}.GB' ; then
      # Everything finished, pack up the results and clean up
      #tar -cf - work/ | gzip -n --best > work.tar.gz
      rm -rf .nextflow/ work/
      cd ..
      tar -cf - ~{output_folder_name}/ | gzip -n --best > ~{output_folder_name}.tar.gz
    else
      # Run failed
      tar -cf - work/ | gzip -n --best > work.tar.gz
      #save line for debugging specific file - just change "collated_versions.yml" to specific file name
      find  /mnt/disks/cromwell_root/phylophx_run/ -path "*work*" -name "*.command.err" | xargs -I {} bash -c "echo {} && cat {}"
      find  /mnt/disks/cromwell_root/phylophx_run/ -path "*work*" -name "*.command.out" | xargs -I {} bash -c "echo {} && cat {}"
      find  /mnt/disks/cromwell_root/phylophx_run/ -name "*.nextflow.log" | xargs -I {} bash -c "echo {} && cat {}"
      exit 1
    fi

    save=$(find  ./ -path "*call-phylophoenix*" | sed 's/.*\(gs:\/\/.*\/call-phylophoenix\).*/\1/')
    echo $save

    #sed 's/.*\(gs:\/\/.*\/call-phylophoenix\).*/\1/' phylophoenix.log | sort -u | tee PROJECT_DIR


  >>>
  output {
    File?  work_files                  = "work.tar.gz"
    String phylophoenix_version        = read_string("VERSION")
    String phylophoenix_docker         = "quay.io/jvhagey/phylophoenix:1.1.0"
    String analysis_date               = read_string("DATE")
    File full_phylophx_results         = "~{output_folder_name}.tar.gz"
    File snvphyl_griphin_excel_summary = "phylophx_run/~{output_folder_name}/SNVPhyl_GRiPHin_Summary.xlsx"
    # "All_<Taxa>_Isolates" directories (combined taxa/complex-level runs)
    Array[File] all_isolates_centroid_info_files = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_centroid_info.txt")
    Array[File] all_isolates_snv_alignment_files = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_snvAlignment.phy")
    Array[File] all_isolates_newick_files        = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_SNVPhyl.newick")
    Array[File] all_isolates_vcf2core_files      = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_vcf2core.tsv")
    Array[File] all_isolates_snv_table_files     = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_snvTable.tsv")
    Array[File] all_isolates_snv_matrix_files    = glob("phylophx_run/~{output_folder_name}/All_*_Isolates/*_snvMatrix.tsv")
    # "<Taxa>_ST###" directories (per-ST runs) - excludes the All_*_Isolates dirs above since those don't match the "_ST" naming pattern
    Array[File]? st_centroid_info_files = glob("phylophx_run/~{output_folder_name}/*_ST*/*_centroid_info.txt")
    Array[File]? st_snv_alignment_files = glob("phylophx_run/~{output_folder_name}/*_ST*/*_snvAlignment.phy")
    Array[File]? st_newick_files        = glob("phylophx_run/~{output_folder_name}/*_ST*/*_SNVPhyl.newick")
    Array[File]? st_vcf2core_files      = glob("phylophx_run/~{output_folder_name}/*_ST*/*_vcf2core.tsv")
    Array[File]? st_snv_table_files     = glob("~{output_folder_name}/*_ST*/*_snvTable.tsv")
    Array[File]? st_snv_matrix_files    = glob("~{output_folder_name}/*_ST*/*_snvMatrix.tsv")
    #full results
    File versions_file = "~{output_folder_name}/pipeline_info/software_versions.yml"
  }
  runtime {
    docker: "quay.io/jvhagey/phylophoenix@sha256:99aef38991e1e94f57fab011d03372e6fe8b6a6397052c06b29312938fd5f326"
    memory: "~{memory} GB"
    cpu: cpu
    disks:  "local-disk ~{disk_size} SSD"
    maxRetries: 0
    preemptible: 0
  }
}