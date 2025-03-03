#
# Copyright (c) 2020 The Broad Institute, Inc. All rights reserved.
#
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_normalize_filter_workflow/versions/15/plain-WDL/descriptor" as norm_filt_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_main/versions/24/plain-WDL/descriptor" as main_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_blacksheep_workflow/versions/26/plain-WDL/descriptor" as blacksheep_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_so_nmf_workflow/versions/14/plain-WDL/descriptor" as so_nmf_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_mo_nmf_gct/versions/41/plain-WDL/descriptor" as mo_nmf_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_immune_analysis_workflow/versions/25/plain-WDL/descriptor" as immune_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_make_pairs_workflow/versions/25/plain-WDL/descriptor" as make_pairs_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_unified_assemble_results/versions/10/plain-WDL/descriptor" as assemble_wdl
import "https://api.firecloud.org/ga4gh/v1/tools/broadcptac:panoply_so_nmf_sankey_workflow/versions/15/plain-WDL/descriptor" as so_nmf_sankey_wdl


workflow panoply_unified_workflow {
  File? prote_ome
  File? phospho_ome
  File? acetyl_ome
  File? ubiquityl_ome
  File? rna_data      #version 1.3 only!
  File? cna_data
  File? sample_annotation
  File yaml
  String job_id
  String run_cmap
  String run_nmf #'true' or 'false'
  Boolean? run_so_nmf #'true' or 'false'
  String? run_ptmsea

  # Normalize specific optional params:
  String? normalizeProteomics # "true" or "false"
  String? filterProteomics # "true" or "false"

  
  Array[File] omes = ["${prote_ome}", "${phospho_ome}", "${acetyl_ome}", "${ubiquityl_ome}"]
  Array[File] data = ["${rna_data}", "${cna_data}"]
  
  # Turn the type data (RNA+CNA) into an array of pairs:
  call make_pairs_wdl.panoply_make_pairs_workflow as type_pairs {
    input:
      files = data,
      suffix = "-subset.gct"

  }

  # Make the array of ome pairs to input into normalize:
  call make_pairs_wdl.panoply_make_pairs_workflow as ome_pairs {
    input:
      files = omes,
      suffix = "-subset.gct"

  }

  ### NORMALIZE:
  ### Normalize the data first so downstream modules (NMF etc) can run in parallel to main:
  scatter (pair in ome_pairs.zipped) {
    if ("${pair.right}" != "") {
      call norm_filt_wdl.panoply_normalize_filter_workflow as norm_filt {
        input:
          input_pome="${pair.right}",
          ome_type="${pair.left}",
          job_identifier="${job_id}-${pair.left}",
          yaml="${yaml}",
          normalizeProteomics=normalizeProteomics,
          filterProteomics=filterProteomics
      }
    }
  }

  # Make an array of pairs from the normalized data for input to main and other modules:
  call make_pairs_wdl.panoply_make_pairs_workflow as norm_filt_pairs {
    input:
      files = norm_filt.filtered_data_table,
      suffix = "-filtered_table-output.gct"

  }

  ### MAIN:
  scatter (pair in norm_filt_pairs.zipped) {
    if ("${pair.right}" != "") {
        call main_wdl.panoply_main as pome {
          input:
            ## include all required arguments from above
            input_pome="${pair.right}",
            ome_type="${pair.left}",
            job_identifier="${job_id}-${pair.left}",
            run_ptmsea="${run_ptmsea}",
            run_cmap = "${run_cmap}",
            run_nmf = "false",
            input_cna="${cna_data}",
            input_rna="${rna_data}",
            sample_annotation="${sample_annotation}",
            yaml="${yaml}"
        }
        
      
    }
  }
  

  # This takes the array of pairs of normalized proteomics data and combines it with the array of pairs of RNA+CNA data for Blacksheep use:
  Array[Pair[String?,File?]] all_pairs = flatten([norm_filt_pairs.zipped,type_pairs.zipped])
  
  ### BLACKSHEEP:
  scatter (pair in all_pairs) {
    if ("${pair.right}" != "") {
      call blacksheep_wdl.panoply_blacksheep_workflow as outlier {
        input:
          input_gct = "${pair.right}",
          master_yaml = "${yaml}",
          output_prefix = "${pair.left}",
          type = "${pair.left}"
      }
    }
  }
  
  ### Single-ome NMF
  call so_nmf_wdl.panoply_so_nmf_workflow as so_nmf {
    input:
      yaml = yaml,
      job_id = job_id,
      prote_ome = norm_filt.filtered_data_table[0],
      phospho_ome = norm_filt.filtered_data_table[1],
      acetyl_ome = norm_filt.filtered_data_table[2],
      ubiquityl_ome = norm_filt.filtered_data_table[3],
      rna_data = rna_data,
      cna_data = cna_data,
      run_sankey = "false" # run sankey_workflow separately
  }

  ### Multi-omics NMF:
  if ( run_nmf == "true" ){
    call mo_nmf_wdl.panoply_mo_nmf_gct_workflow as mo_nmf {
      input:
        yaml_file = yaml,
        label = job_id,
        omes = norm_filt.filtered_data_table,
        rna_ome = rna_data,
        cna_ome = cna_data
    }
  }
  
  ### NMF Sankey Diagrams (SO and MO nmf)
  if ( run_so_nmf ){
    call so_nmf_sankey_wdl.panoply_so_nmf_sankey_workflow as all_nmf_sankey {
    input:
      so_nmf_tar = so_nmf.nmf_results,
      mo_nmf_tar = mo_nmf.nmf_clust, #will exist if mo_nmf was run
      label = job_id
    }
  }
  
  ### IMMUNE:
  if ( "${rna_data}" != '' ) {
    call immune_wdl.panoply_immune_analysis_workflow as immune {
      input:
          inputData=rna_data,
          standalone="true",
          type="rna",
          yaml=yaml,
          analysisDir=job_id,
          label=job_id
    }
  }
  
  ## assemble final output combining results from panoply_main, blacksheep immune_analysis and mo_nmf
  call assemble_wdl.panoply_unified_assemble_results {
    input:
      main_full = pome.panoply_full,
      main_summary = pome.summary_and_ssgsea,
      cmap_output = pome.cmap_output,
      cmap_ssgsea_output = pome.cmap_ssgsea_output,
      norm_report = norm_filt.normalize_report,
      rna_corr_report = pome.rna_corr_report,
      cna_corr_report = pome.cna_corr_report,
      omicsev_report = pome.omicsev_report,
      cosmo_report = pome.cosmo_report,
      sampleqc_report = pome.sample_qc_report,
      assoc_report = pome.association_report,
      blacksheep_tar = outlier.blacksheep_tar,
      blacksheep_report = outlier.blacksheep_report,
      so_nmf_results = so_nmf.nmf_results,
      so_nmf_reports = so_nmf.nmf_reports,
      so_nmf_sankey_results = all_nmf_sankey.sankey_tar,
      so_nmf_sankey_report = all_nmf_sankey.sankey_report,
      mo_nmf_tar = mo_nmf.nmf_clust,
      mo_nmf_report = mo_nmf.nmf_clust_report,
      mo_nmf_ssgsea_tar = mo_nmf.nmf_ssgsea,
      mo_nmf_ssgsea_report = mo_nmf.nmf_ssgsea_report,
      immune_tar = immune.outputs,
      immune_report = immune.report

  }
  
  output {
    File all_results = panoply_unified_assemble_results.all_results
    File all_reports = panoply_unified_assemble_results.all_reports
  }
 }