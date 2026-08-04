version 1.0

import "../tasks/task_phylophoenix.wdl" as phylophoenix_nf

workflow phylophoenix_workflow {
  meta {
    description: "A WDL wrapper around the phylophoenix pipeline to facilitate genomic relatedness analysis."
  }
  input {
    Array[File] current_full_results
    Int?        window_size
    String      output_folder_name
    Boolean?    no_all
    Boolean?    by_st
    Boolean?    use_secondary_mlst
    Boolean?    combine_complex
    File?       blind_list
  }
  call phylophoenix_nf.phylophoenix {
    input:
      current_full_results = current_full_results,
      output_folder_name   = output_folder_name,
      window_size          = window_size,
      no_all               = no_all,
      by_st                = by_st,
      use_secondary_mlst   = use_secondary_mlst,
      combine_complex      = combine_complex,
      blind_list           = blind_list
  }
  output {
    #phylophoenix summary output values
    File? work_files                   = phylophoenix.work_files
    String phylophoenix_version        = phylophoenix.phylophoenix_version
    String phylophoenix_docker         = phylophoenix.phylophoenix_docker
    String analysis_date               = phylophoenix.analysis_date
    File full_phylophx_results         = phylophoenix.full_phylophx_results
    File snvphyl_griphin_excel_summary = phylophoenix.snvphyl_griphin_excel_summary
    # "All_<Taxa>_Isolates" directories (combined taxa/complex-level runs)
    Array[File]? all_isolates_centroid_info_files = phylophoenix.all_isolates_centroid_info_files
    Array[File]? all_isolates_snv_alignment_files = phylophoenix.all_isolates_snv_alignment_files
    Array[File]? all_isolates_newick_files        = phylophoenix.all_isolates_newick_files
    Array[File]? all_isolates_vcf2core_files      = phylophoenix.all_isolates_vcf2core_files
    Array[File]? all_isolates_snv_table_files     = phylophoenix.all_isolates_snv_table_files
    Array[File]? all_isolates_snv_matrix_files    = phylophoenix.all_isolates_snv_matrix_files
    # "<Taxa>_ST###" directories (per-ST runs) - excludes the All_*_Isolates dirs above since those don't match the "_ST" naming pattern
    Array[File]? st_centroid_info_files  = phylophoenix.st_centroid_info_files
    Array[File]? st_snv_alignment_files  = phylophoenix.st_snv_alignment_files
    Array[File]? st_newick_files         = phylophoenix.st_newick_files
    Array[File]? st_vcf2core_files       = phylophoenix.st_vcf2core_files
    Array[File]? st_snv_table_files      = phylophoenix.st_snv_table_files
    Array[File]? st_snv_matrix_files     = phylophoenix.st_snv_matrix_files
    File versions_file                   = phylophoenix.versions_file             # software_versions.yml"
  }
}