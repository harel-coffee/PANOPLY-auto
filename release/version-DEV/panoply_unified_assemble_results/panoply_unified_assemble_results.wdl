#
# Copyright (c) 2020 The Broad Institute, Inc. All rights reserved.
#
task panoply_unified_assemble_results {
  Array[File?] main_full
  Array[File?] main_summary
  Array[File?] norm_report
  Array[File?] rna_corr_report
  Array[File?] cna_corr_report
  Array[File?] omicsev_report
  Array[File?] cosmo_report
  Array[File?] sampleqc_report
  Array[File?] assoc_report
  Array[File?] blacksheep_tar
  Array[File?] blacksheep_report
  Array[File?] cmap_output
  Array[File?] cmap_ssgsea_output
  File? so_nmf_results
  File? so_nmf_reports
  File? so_nmf_sankey_results
  File? so_nmf_sankey_report
  File? mo_nmf_tar
  File? mo_nmf_report
  File? mo_nmf_ssgsea_tar
  File? mo_nmf_ssgsea_report
  File? immune_tar
  File? immune_report

  String output_results_zip = "all_results.zip"
  String output_reports_zip = "all_reports.zip"

  Int? memory
  Int? disk_space
  Int? num_threads
  Int? num_preemptions

  command {
    set -euo pipefail

    ### Setup RESULTS and REPORTS directory structure
    mkdir results
    mkdir results/proteogenomics_analysis results/blacksheep_outlier results/so-nmf results/mo-nmf results/immune_analysis
    mkdir reports
    mkdir reports/proteogenomics_analysis reports/blacksheep_outlier reports/so-nmf reports/mo-nmf reports/immune_analysis

    ### Dump results files into the given folders
    # MAIN 
    if [ ${sep='' main_full} != '' ]; then
      mv ${sep=' ' main_full} results/proteogenomics_analysis
      for filename in results/proteogenomics_analysis/*.tar;do tar -C results/proteogenomics_analysis -xvf $filename;rm $filename;done
    fi

    if [ ${sep='' main_summary} != '' ]; then
      mkdir results/proteogenomics_analysis/summary_files
      mv ${sep=' ' main_summary} results/proteogenomics_analysis/summary_files
      for filename in results/proteogenomics_analysis/summary_files/*.tar;do tar -C results/proteogenomics_analysis/summary_files -xvf $filename;rm $filename;done
    fi
    
    if [ ${sep='' cmap_output} != '' ]; then
      mkdir results/proteogenomics_analysis/proteome_cmap_analysis
      mv ${sep=' ' cmap_output} results/proteogenomics_analysis/proteome_cmap_analysis
      for filename in results/proteogenomics_analysis/proteome_cmap_analysis/*.tar;do tar -C results/proteogenomics_analysis/proteome_cmap_analysis -xvf $filename;rm $filename;done
    fi
    
    if [ ${sep='' cmap_ssgsea_output} != '' ]; then
      mv ${sep=' ' cmap_ssgsea_output} results/proteogenomics_analysis/proteome_cmap_analysis
      for filename in results/proteogenomics_analysis/proteome_cmap_analysis/*.tar;do tar -C results/proteogenomics_analysis/proteome_cmap_analysis -xvf $filename;rm $filename;done
    fi

    # MAIN REPORTS
    mkdir results/proteogenomics_analysis/all_html_reports
    if [ ${sep='' norm_report} != '' ]; then
      cp ${sep=' ' norm_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' norm_report} reports/proteogenomics_analysis
    fi

    if [ ${sep='' rna_corr_report} != '' ]; then
      cp ${sep=' ' rna_corr_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' rna_corr_report} reports/proteogenomics_analysis
    fi

    if [ ${sep='' cna_corr_report} != '' ]; then
      cp ${sep=' ' cna_corr_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' cna_corr_report} reports/proteogenomics_analysis
    fi

	  if [ ${sep='' omicsev_report} != '' ]; then
      cp ${sep=' ' omicsev_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' omicsev_report} reports/proteogenomics_analysis
    fi
    
    if [ ${sep='' cosmo_report} != '' ]; then
      cp ${sep=' ' cosmo_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' cosmo_report} reports/proteogenomics_analysis
    fi

    if [ ${sep='' sampleqc_report} != '' ]; then
      cp ${sep=' ' sampleqc_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' sampleqc_report} reports/proteogenomics_analysis
    fi

    if [ ${sep='' assoc_report} != '' ]; then
      cp ${sep=' ' assoc_report} results/proteogenomics_analysis/all_html_reports
      mv ${sep=' ' assoc_report} reports/proteogenomics_analysis
    fi
    

    # BLACKSHEEP
    if [ ${sep='' blacksheep_tar} != '' ]; then
      mv ${sep=' ' blacksheep_tar} results/blacksheep_outlier
      for filename in results/blacksheep_outlier/*.tar;
      do 
        folder=$(basename $filename _blacksheep.tar)
        if [ ! -d $folder ]; then
          mkdir results/blacksheep_outlier/$folder
        fi
        tar -C results/blacksheep_outlier/$folder -xvf $filename
        rm $filename
      done
    fi

    if [ ${sep='' blacksheep_report} != '' ]; then
      mkdir results/blacksheep_outlier/reports
      cp ${sep=' ' blacksheep_report} results/blacksheep_outlier/reports
      mv ${sep=' ' blacksheep_report} reports/blacksheep_outlier
    fi

    # SO-NMF
    if [ ${so_nmf_results} != '' ]; then #has results and reports
      mv ${so_nmf_results} results/so-nmf
      for filename in results/so-nmf/*.tar;do tar -C results/so-nmf -xvf $filename --strip-components 1;rm $filename;done
    fi
    if [ ${so_nmf_reports} != '' ]; then #has just reports
      mv ${so_nmf_reports} reports/so-nmf
      for filename in reports/so-nmf/*.tar;do tar -C reports/so-nmf -xvf $filename --strip-components 2;rm $filename;done
      # report files are already in so_nmf_results tar, do not recopy
    fi
    if [ ${so_nmf_sankey_results} != '' ]; then
      mkdir results/so-nmf/sankey
      mv ${so_nmf_sankey_results} results/so-nmf/sankey
      for filename in results/so-nmf/sankey/*.tar;do tar -C results/so-nmf/sankey -xvf $filename;rm $filename;done
    fi
    if [ ${so_nmf_sankey_report} != '' ]; then
      cp ${so_nmf_sankey_report} results/so-nmf/sankey
      mv ${so_nmf_sankey_report} reports/so-nmf
    fi

    # MO-NMF
    mkdir results/mo-nmf/mo-nmf
    if [ ${mo_nmf_tar} != '' ]; then
      mv ${mo_nmf_tar} results/mo-nmf/mo-nmf
      for filename in results/mo-nmf/mo-nmf/*.tar;do tar -C results/mo-nmf/mo-nmf -xvf $filename;rm $filename;done
    fi
    
    mkdir results/mo-nmf/mo-nmf_report
    if [ ${mo_nmf_report} != '' ]; then
      cp ${mo_nmf_report} results/mo-nmf/mo-nmf_report
      mv ${mo_nmf_report} reports/mo-nmf
    fi
    
  mkdir results/mo-nmf/mo-nmf_ssgsea
    if [ ${mo_nmf_ssgsea_tar} != '' ]; then
      mv ${mo_nmf_ssgsea_tar} results/mo-nmf/mo-nmf_ssgsea
      for filename in results/mo-nmf/mo-nmf_ssgsea/*.tar.gz;do tar -C results/mo-nmf/mo-nmf_ssgsea -zxvf $filename;rm $filename;done
    fi

  mkdir results/mo-nmf/mo-nmf_ssgsea_report
    if [ ${mo_nmf_ssgsea_report} != '' ]; then
      cp ${mo_nmf_ssgsea_report} results/mo-nmf/mo-nmf_ssgsea_report
      mv ${mo_nmf_ssgsea_report} reports/mo-nmf
    fi

    # IMMUNE
    if [ ${immune_tar} != '' ]; then
      mv ${immune_tar} results/immune_analysis
      for filename in results/immune_analysis/*.tar;do tar -C results/immune_analysis -xvf $filename;rm $filename;done
    fi
    if [ ${immune_report} != '' ]; then
      cp ${immune_report} results/immune_analysis
        mv ${immune_report} reports/immune_analysis
    fi

    ### Zip up final directories
    zip ${output_results_zip} -r results
    zip ${output_reports_zip} -r reports

  }

  output {
    File all_results = "${output_results_zip}"
    File all_reports = "${output_reports_zip}"

  }
  
  runtime {
    docker : "broadcptacdev/panoply_common:DEV"
    memory : select_first ([memory, 16]) + "GB"
    disks : "local-disk " + select_first ([disk_space, 32]) + " SSD"
    cpu : select_first ([num_threads, 1]) + ""
    preemptible : select_first ([num_preemptions, 0])
  }

  meta {
    author : "Myranda Maynard"
    email : "proteogenomics@broadinstitute.org"
  }
}

workflow panoply_unified_assemble_results_workflow {
  call panoply_unified_assemble_results
}