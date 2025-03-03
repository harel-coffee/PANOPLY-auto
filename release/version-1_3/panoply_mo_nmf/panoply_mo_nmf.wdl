#
# Copyright (c) 2020 The Broad Institute, Inc. All rights reserved.
#

######################################
## NMF
task panoply_mo_nmf {

	#Inputs defined here
	File tar_file
	File yaml_file
	String output_prefix="results_nmf"
	
	Int? kmin
	Int? kmax
	Int? nrun
	
	String? seed
	
	String? gene_column
 
	Boolean? no_plot
	Boolean? z_score
	Boolean? impute

	Boolean? exclude_2
	
	String? filt_mode
	Float? sd_min

	Int? memory
	Int? disk_space
	Int? num_threads
	Int? num_preemtions
	
	command {
		set -euo pipefail
		#Command goes here
		Rscript /home/pgdac/src/mo-nmf.r --tar ${tar_file} --yaml ${yaml_file} --lowrank ${default=NA kmin} --maxrank ${default=NA kmax} --nrun ${default=NA nrun} --seed ${default=NA seed} --runonly ${default=false no_plot} --sdfilter ${default=NA sd_min} --filt_mode ${default=NA filt_mode} --z_score ${default=NA z_score} --impute ${default=NA impute} --gene_column ${default=NA gene_column} --exclude_2 ${default=NA exclude_2} --libdir /home/pgdac/src/

		find * -type d -name "[0-9]*" -print0 | tar -czvf ${output_prefix}.tar --null -T -
		
		find . -name "matrix_W_combined_signed.gct" | xargs cp -t .
		}

	output {
		#Outputs defined here
		File results="${output_prefix}.tar"
		File feature_matrix_w="matrix_W_combined_signed.gct"
		}

	runtime {
		docker : "broadcptac/panoply_mo_nmf:1_3"
		memory : select_first ([memory, 64]) + "GB"
		disks : "local-disk " + select_first ([disk_space, 20]) + " HDD"
		cpu : select_first ([num_threads, 32]) + ""
		preemptible : select_first ([num_preemtions, 0])
	}

	meta {
		author : "Karsten Krug"
		email : "karsten@broadinstitute.org"
	}

}

################################################
##  workflow: mo-nmf
workflow panoply_mo_nmf_workflow {
	
	File tar_file
	File yaml_file
	
	call panoply_mo_nmf {
		input:
			tar_file=tar_file,
			yaml_file=yaml_file
	}

	output {
		File nmf_clust=panoply_mo_nmf.results
		}
}
