#!/usr/bin/env Rscript
options( warn = -1 )
args <- commandArgs(trailingOnly=T)

## get arguments
snv.filelist.tsv <- args[1]
indel.filelist.tsv <- args[2]
junc.filelist.tsv <- args[3]
id <- args[4]

## used to extract annotation files
##tmp.dir <- '/tmp/'

## ######################################################################################################
##
##                Generate a consensus FASTA file from multiple FASTA files generated by
##                the 'pgdac_cpdb' workflow.
##
##   input:   	- list of files, nsSNVs
##        		- list of files, indels
##			- list of files, splice junctions
##de
##   output:	- non-redundant FASTA file representing a consensus database of all input files
##              - generate a Rmarkdown report that summarizes the results
##
## ######################################################################################################
aggregate_fasta <- function(snv.filelist.tsv, indel.filelist.tsv, junc.filelist.tsv, prefix='test',  tmp.dir='.'){

	require(seqinr)

   	## ###########################################
        ## prepare log file
        logfile=paste('cpdb_aggregate_', prefix, '.log', sep='')
        start.time <- Sys.time()
        cat(paste(rep('#', 40), collapse=''),'\n##', paste0(start.time), '--\'run_cpdb\'--\n\n', file=logfile)

	## ###########################################
	## prepare Rmarkdown file
	rmd=paste('cpdb_aggregate_', prefix, '.Rmd', sep='')
	cat('# Report of CustomProDB pipeline\n', start.time, '\n', file=rmd)



	## ###########################################
	## import SNV fasta
	cat('\n## importing SNV FASTA...\n', file=logfile, append=T)

	snv.filelist <- readLines(snv.filelist.tsv)
	snv <- lapply(snv.filelist, read.fasta)



	## ############################################
        cat('done\n' ,file=logfile, append=T)
        cat('\nTotal time:', paste0(format(Sys.time() - start.time)), file=logfile, append=T)

    return(0)
} ## end function 'aggregate_fasta'


## #####################################################
##
debug(aggregate_fasta)
res <- aggregate_fasta(snv.filelist.tsv=snv.filelist.tsv, indel.filelist.tsv=indel.filelist.tsv, junc.filelist.tsv=junc.filelist.tsv, prefix=id, tmp.dir=tmp.dir )


