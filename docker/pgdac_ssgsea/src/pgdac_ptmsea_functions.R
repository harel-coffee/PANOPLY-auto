#
# Copyright (c) 2020 The Broad Institute, Inc. All rights reserved.
#
## install pacman and cmapR packages
if(!require(pacman)){install.packages("pacman");library(pacman)}

## make sure 'rhdf5' is loaded BEFORE 'cmapR'
if(!suppressPackageStartupMessages(require(rhdf5))){
  source("https://bioconductor.org/biocLite.R")
  biocLite("rhdf5")
}
if(!suppressPackageStartupMessages(require(cmapR)))
  devtools::install_github("cmap/cmapR")


## ###################################################################
# preprocess GCT file for subsequent ssGSEA/PTM-SEA analysis, e.g.
# - create site-centric GCT
# - create PTMsigDB compatible site identifier
# - create gene-centric GCT for ssGSEA; not implemented yet
#
preprocessGCT <- function(
  gct.str='',                         ## path to GCT file 
  level=c('ssc', 'gc', 'gcr'),        ## single-site-centric, gene-centric or gene-centric-redundant reports
  id.type=c('sm', 'wg', 'ph'),        ## notation of site-ids: sm-Spectrum Mill; wg-Web Gestalt; ph-Philosopher
  id.type.out=c('uniprot', 'refseq', 'seqwin', 'psp'), ## type of site id for output; psp not implemented yet
  acc.type=c('uniprot', 'refseq', 'symbol'),  ## accession type of 'rid' object in GCT file
  seqwin.col='VMsiteFlanks',          ## column containing flanking sequences, separated by '|'. Only relevant
                                      ## if if.type.out = 'seqwin'           
  gene.col='geneSymbol',              ## name of column listing gene names; used for gene centric reports and to fix gene names 
  fix.gene.names=F,                   ## if TRUE, try to fix the gene2date conversion problem; works for site-centric reports as well
  fix.gene.names.column='id.description', ## alternative column in rdesc containing gene names that
                                          ## can be used to fix gene names, e.g. description: 'septin-10 isoform 4 GN=SEPT10'
  fix.gene.names.regexpr='.* GN\\=(.*)$', ## regular expression to extract gene names from 'fix.gene.names.column'
  loc=T,                              ## if TRUE only fully localized sites will be considered
  mode=c('mean', 'median', 'sd', 'SGT', 'abs.max'),     ## how should multiple sites per gene be combine; 
                                      ## sd - most variable (standard deviation) across sample columns
                                      ## SGT - subgroup top: first subgroup in protein group (spectrum mill)
                                      ## for log-transformed, signed p-values
  SGT.col='subgroupNum',              ## column used to collpase to SGT        
  mod.res=c('S|T|Y', 'K'),            ## modified residue(s) 
  mod.type=c('p', 'ac', 'ub'),        ## modification type
  #map2up=T,                          ## if TRUE, RefSeq and GeneSymbols will be mapped to UniProt 
  #org=c('human', 'mouse', 'rat'),    ## supported organism; parameter not used right now; function 'RefSeq2UniProt' tries to determine organism automatically
  appenddim=T,                        ## see cmapR::write.gct()
  use.as.is=F                         ## flag, if TRUE nothing will be done; probably needed for to make this step optional in a FireCLoud WDL.
){
  
  ## imediatly return
  if(use.as.is){
    return(gct.str)
  }
  
  require(pacman)
  p_load(cmapR)
  p_load(magrittr)
  p_load(glue)
  p_load(dplyr)
  
  #parse paramters----
  level <- match.arg(level)
  mode <- match.arg(mode)
  mod.res <- match.arg(mod.res)
  mod.type <- match.arg( mod.type )
  acc.type <- match.arg( acc.type )
  #org <- match.arg(org)
  id.type <- match.arg(id.type)
  id.type.out<- match.arg(id.type.out)
  
  
  #import GCT---------
  if(file.exists(gct.str)){
      cat('importing gct file: ', gct.str, ' ...\n')
      gct <- try(parse.gctx(gct.str))
      cat(class(gct), '\n')
      #g <- readLines(gct.str)
      #cat(g[1:3],'\n')
  } else {
    stop(glue("File '{gct.str}' not found!\n"))
  }
  cat('\ntest1\n')
  if(class(gct) == 'try-error'){
    
    ## - cmapR functions stop if ids are not unique
    ## - import gct using readLines and make ids unique
    if(length(grep('rid must be unique', gct) ) > 0) {
      gct.tmp <- readLines(gct.str)
      #first column
      rid <- gct.tmp %>% sub('\t.*','', .)
      #data and meta data columns
      meta <- strsplit(gct.tmp[2], '\t') %>% unlist() %>% as.numeric()
      rid.idx <- (meta[4]+3) : length(rid)
      #check whether ids are unique
      if(length(rid[rid.idx]) > length(unique(rid[rid.idx]))){
        warning('rids not unique! Making ids unique and exporting new GCT file...\n\n')
        #make unique
        rid[rid.idx] <- make.unique(rid[rid.idx])
        #other columns
        rest <- gct.tmp %>% sub('.*?\t','', .)
        rest[1] <- ''
        gct.tmp2 <- paste(rid, rest, sep='\t') 
        gct.tmp2[1] <-  sub('\t.*','',gct.tmp2[1])
        #export
        gct.unique <- sub('\\.gct', '_unique.gct', gct.str)
        writeLines(gct.tmp2, con=gct.unique)
        
        gct <- parse.gctx(fname = gct.unique)
      }
    } #end if 'rid not unique'
  }
  cat('done\n')
  
  ##############################################
  #parse GCT object
  mat <- gct@mat
  cat('\ntest2\n')
  n <- ncol(mat) ## number of data colums
  
  ## row ids
  rid <- gct@rid
  
  ## remove blanks in SM VM site ids
  ##rid <- sub('\\._', '_', rid)
  if(is.null(rid)) rid <- rownames(mat)
  cid <- gct@cid
  if(is.null(cid)) cid <- colnames(mat)
  cdesc <- gct@cdesc
  #cdesc.ids <- colnames(cdesc)
  rdesc <- gct@rdesc
  #rdesc.ids <- colnames(rdesc)
  
  ## ###########################################
  ## fix gene names affected by gene2date conversion
  if(fix.gene.names){
    
    if(!gene.col %in% colnames(rdesc))
      stop(glue("Column {gene.col} not found!"))
    
    if(!fix.gene.names.column %in% colnames(rdesc))
      stop(glue("Column {fix.gene.names.column} not found!"))
    
    genes <- sub(fix.gene.names.regexpr, '\\1', rdesc[, fix.gene.names.column])
    rdesc[, gene.col] <- genes  
  }
  
  ## #######################################################
  ##
  ##                 gene-centric-redundant
  ##
  ## #######################################################
  if(level == 'gcr'){
   
     if(!gene.col %in% colnames(rdesc))
      stop(glue("Column {gene.col} not found!"))
    
    genes <- rdesc[, gene.col]
    
    ## remove empty cells
    rm.idx <- which(is.na(genes) | nchar(genes) == 0)
    if(length(rm.idx) > 0){
      genes <- genes[-rm.idx]
      rid <- rid[ -rm.idx ]
      if(n == 1){
        mat <- data.frame( matrix(mat[-rm.idx, ], ncol=1, dimnames=list(rid, cid)) )
      } else {
        mat <- mat[-rm.idx, ]
      }
      rdesc <- rdesc[-rm.idx,]
     # rid <- rid[ -rm.idx ]
      warning(glue("Removed {length(rm.idx)} rows due to missing gene symbol in column '{gene.col}'\n\n"))
    }
    
    ## non-redundant gene symbols as rid
    rid <- genes

    # GCT
    gct@mat <- data.matrix(mat)
    gct@rid <- make.unique(rid, sep = '_')
    gct@cid <- cid
    gct@cdesc <- cdesc
    gct@rdesc <- rdesc
    
  }
  
  ## #######################################################
  ##
  ##                   gene-centric (gc)
  ##
  ## #######################################################
  if(level == 'gc'){
    
    if(!gene.col %in% colnames(rdesc))
      stop(glue("Column {gene.col} not found!"))
    
    genes <- rdesc[, gene.col]
    ## remove empty cells
    rm.idx <- which(is.na(genes) | nchar(genes) == 0)
    if(length(rm.idx) > 0){
      genes <- genes[-rm.idx ]
      rid <- rid[ -rm.idx ]
     # mat <- mat[-rm.idx, ] %>% data.frame
      if(n == 1){
        mat <- matrix(mat[-rm.idx, ], ncol=1, dimnames=list(rid, cid))
      } else {
        mat <- mat[-rm.idx, ]
      }
      rdesc <- rdesc[-rm.idx,]
      warning(glue("Removed {length(rm.idx)} rows due to missing gene symbol in column '{gene.col}'\n\n"))
    }
    
    ## aggregate data
    if(mode == 'mean')
      mat.gc <- aggregate(mat, FUN=function(x) mean(x, na.rm=T), by=list(genes))
        
    if(mode == 'median')
      mat.gc <- aggregate(mat, FUN=function(x) median(x, na.rm=T), by=list(genes))
    
    if(mode == 'SGT'){
      # 1. extract top subgroup
      # 2. collapse to genes by taking median expression
      
      if(!SGT.col %in% colnames(rdesc)) stop(glue("Column {SGT.col} not found!"))
      
      sgt <- rdesc[, SGT.col] %>% sub('\\..*', '', .)
      mat.sgt <- aggregate(mat, FUN=function(x) x[1], by=list(sgt))
      mat.sgt <- mat.sgt[, -c(1)]
      
      ## aggregate rdesc to SGT
      rdesc.sgt <- aggregate(rdesc, FUN=function(x) x[1], by=list(sgt))
      rdesc.sgt <- rdesc.sgt[, -c(1)]
      
      ## make gen-centric using median expression
      genes <- rdesc.sgt[, gene.col]
      mat.gc <- aggregate(mat.sgt, FUN=function(x) median(x, na.rm=T), by=list(genes))
      rdesc <- rdesc.sgt
    }
    if(mode == 'abs.max'){
      mat.gc <- aggregate(mat, FUN=function(x)x[ which.max(abs(x)) ], by=list(genes))     
    }
  
    ## non-redundant gene symbols as rid
    rid <- mat.gc[, 1]
    #mat.gc <- mat.gc[, -c(1)] %>% data.frame
    if(n == 1) {
      mat.gc <- data.frame( matrix(mat.gc[, -c(1)], ncol=1, dimnames=list(rid, cid)))
    } else {
      mat.gc <- mat.gc[, -c(1)]
    }
    ## aggregate rdesc
    rdesc.gc <- aggregate(rdesc, FUN=function(x) paste(unique(x), collapse='|'), by=list(genes))
    rdesc.gc <- rdesc.gc[, -c(1)]
    
    # GCT
    rownames(mat.gc) <- rownames(rdesc.gc) <- rid
    gct@mat <- data.matrix(mat.gc)
    gct@rid <- rid
    gct@cid <- cid
    gct@cdesc <- cdesc
    gct@rdesc <- rdesc.gc
    
  } ## end if level=='gc'
  
  
  ## ###################################################################
  ##
  ##                single site-centric table (ssc)
  ##
  ## ###################################################################
  if(level == 'ssc'){
    
    #row ids are site ids
    site.ids <- rid
    names(site.ids) <- rid
    site.ids <- gsub(' ', '', site.ids )
    
  
    ## #####################################
    ##   make ids UniProt-centric
    ## #####################################
    if(id.type.out == 'uniprot'){
    
         
      # In case of RefSeq accession, remove all non-RefSeq accession numbers,
      # e.g. UniProt accessions of lab contaminants
      # then map RefSeq to UniProt
      if(acc.type == 'refseq'){
        
        #refseq only
        idx <- grep('^(NP_|XP_|YP_|ZP_)', site.ids)
        site.ids <- site.ids[idx]
        
        # update GCT
        rid <- rid[idx]
        if(n == 1){
          mat <- matrix(mat[idx, ], ncol=n)
          dimnames(mat) <- list(rid, cid)
        } else {
          mat <- mat[idx, ]
        }
        rdesc <- rdesc[idx, ]
        
        #map to UniProt
        #if(map2up){
        if(id.type.out == 'uniprot')
          up <- RefSeq2UniProt( sub('^(.*?_.*?)_.*', '\\1', site.ids) )$id.map$id.mapped
        mapped.idx <- which(!is.na(up))
        
        ## update
        up <- up[mapped.idx]
        site.ids <- site.ids[mapped.idx]
        rid <- rid[mapped.idx]
        
        if(n == 1){
          mat <- matrix(mat[mapped.idx, ], ncol=ncol(mat))
          dimnames(mat) <- list(rid, cid)
        } else{
          mat <- mat[mapped.idx, ]
        }
        
        rdesc <- rdesc[mapped.idx, ]
        #rdesc <- matrix(rdesc[mapped.idx, ], ncol=length(rdesc.ids))
        #dimnames(rdesc) <- list(rid, rdesc.ids)
        
        site.ids <- paste(up, sub('^(.*?_.*?)(_.*)', '\\2', site.ids), sep='')
        names(site.ids) <- rid
      } ## end acc.type == 'refseq'
     
       
      ## ##############################
      ## gene symbol + site
      ## EIF2S2.S2
      if(acc.type == 'symbol'){
      
        #map to UniProt
        up <- RefSeq2UniProt( sub('^(.*?)-.*', '\\1', site.ids), keytype = 'SYMBOL' )$id.map$id.mapped
        mapped.idx <- which(!is.na(up))
      
        ## update
        up <- up[mapped.idx]
        upte.ids <- site.ids[mapped.idx]
        rid <- rid[mapped.idx]
      
        if(n == 1){
          mat <- matrix(mat[mapped.idx, ], ncol=ncol(mat))
          dimnames(mat) <- list(rid, cid)
        } else {
          mat <- mat[mapped.idx, ]
        }
        
        rdesc <- rdesc[mapped.idx, ]
        #rdesc <- matrix(rdesc[mapped.idx, ], ncol=ncol(rdesc))
        #dimnames(rdesc) <- list(rid, rdesc.ids)
        
        ## create PTM-SEA compatible ids
        #site.ids <- glue("{up};{sub('^(.*?)\\\\.(.*)', '\\\\2', site.ids)}{mod.type}")
        site.ids <- glue("{up};{sub('^(.*?)-(.*)', '\\\\2', site.ids)}-{mod.type}")
        
        names(site.ids) <- rid
      } ## acc.type == 'symbol'
      
      #############################
      ## UniProt
      if(acc.type == 'uniprot'){
        site.ids <- site.ids
        names(site.ids) <- rid
      }
    } ## end id.type.out == 'uniprot'
    
    
    ## ####################################
    ## extract all sites per entry
    ## ####################################
    
    ## Spectrum Mill VM site ids
    if(id.type == 'sm'){
      
      if(loc){
        #localized sites----
        # - index of fully localized sites 
        loc.idx <- which( sapply (strsplit(sub('^.*_([1-9]_[0-9])_.*', '\\1', site.ids), '_'), function(x)length(unique(x)) ) == 1)
        
        
        # update GCT
        rid <- rid[ loc.idx ]
        site.ids <- site.ids[ loc.idx ]

        if(n == 1){
          mat <- matrix(mat[loc.idx, ], ncol=ncol(mat))
          dimnames(mat) <- list(rid, cid)
        } else {
          mat <- mat[loc.idx, ]
        }
        rdesc <- rdesc[loc.idx,]
      
      }
      
      ## ##################################################
      ## variable sites

      ## RefSeq-centric site ids
      if(acc.type == 'refseq' & id.type.out %in% c('refseq')){
        
        idx <- grep('^(NP_|XP_|YP_|ZP_)', site.ids)
        site.ids <- site.ids[idx]
        rdesc <- rdesc[idx, ]
        
        site.var <- sub('^(.{2}_.*?_.*?)_.*', '\\1', site.ids)
        names(site.var) <- names(site.ids)
        
        ## accession number plus modified residue
        all.sites <- lapply( strsplit(site.var, tolower(mod.res)), function(x){ 
          prot.acc=sub('^(.{2}_.*?)_.*', '\\1', x[1])
          x=sub(paste0(prot.acc,'_'), '', x)
          paste(prot.acc, grep( toupper(mod.res), x, value=T), sep=';' )
          
        })
      ## sequence windows   
      } else  if( id.type.out == 'seqwin'){
        
        if(!seqwin.col %in% colnames(rdesc)) stop(glue("column '{seqwin.col}' not found!"))
        
        site.var <- rdesc[, seqwin.col] %>% toupper %>% gsub('-', '_', .)
        names(site.var) <- names(site.ids)
        
        all.sites <- strsplit(site.var, '\\|')
        
        
      } else {
        
        ## UniProt-centric site ids
        site.var <- sub('^(.*?_.*?)_.*', '\\1', site.ids)
        names(site.var) <- names(site.ids)
        
        ## accession number plus modified residue
        all.sites <- lapply( strsplit(site.var, tolower(mod.res)), function(x){ 
          prot.acc=sub('_.*', '', x[1])
          x=sub('.*?_', '', x)
          paste(prot.acc, grep( toupper(mod.res), x, value=T), sep=';' )
          
        })
        
      }
      
    } # end if Spectrum Mill VM ids
    
    ## ###############################
    ## Michigan pipeline Philosopher
    if(id.type == 'ph'){
      
      ## localized sites
      loc.idx <- which( sapply (strsplit(sub('^.*_([1-9]_[0-9])_{0,1}.*', '\\1', site.ids), '_'), function(x) x[2] > 0 ) )
      # update GCT
      rid <- rid[ loc.idx ]
      site.ids <- site.ids[ loc.idx ]
      
      if(n == 1){
        mat <- matrix(mat[loc.idx, ], ncol=ncol(mat))
        dimnames(mat) <- list(rid, cid)
      } else {
        mat <- mat[loc.idx, ]
      }
      rdesc <- rdesc[loc.idx,]
      
      
      ## RefSeq-centric site ids
      if(acc.type == 'refseq' & id.type.out %in% c('refseq')){
        
        idx <- grep('^(NP_|XP_|YP_|ZP_)', site.ids)
        site.ids <- site.ids[idx]
        rdesc <- rdesc[idx, ]
        
        site.var <- site.ids %>% sub('.*_', '', .) %>% gsub('([0-9])([A-Z])','\\1 \\2', .)
        prot.acc <-  site.ids %>% sub('^(.{2}_.*?\\.[0-9]{1,2})_.*','\\1', .)
        
        site.var <- paste(prot.acc, site.var, collapse='_')
        
        names(site.var) <- names(site.ids)
        
        ## accession number plus modified residue
        all.sites <- lapply( strsplit(site.var, ' '), function(x){
          
          prot.acc=sub('^(.{2}_.*?)_.*', '\\1', x[1])
          x=sub(paste0(prot.acc,'_'), '', x)
          paste(prot.acc, grep( toupper(mod.res), x, value=T), sep=';' )
          
        })
        
        ## sequence windows   
      } else  if( id.type.out == 'seqwin'){
        
        if(!seqwin.col %in% colnames(rdesc)) stop(glue("column '{seqwin.col}' not found!"))
        
        site.var <- rdesc[, seqwin.col] %>% toupper %>% gsub('-', '_', .)
        names(site.var) <- names(site.ids)
        
        all.sites <- strsplit(site.var, '\\|')
        
        
      } else {
        
        ## UniProt-centric site ids
        site.var <- sub('^(.*?_.*?)_.*', '\\1', site.ids)
        names(site.var) <- names(site.ids)
        
        ## accession number plus modified residue
        all.sites <- lapply( strsplit(site.var, tolower(mod.res)), function(x){ 
          prot.acc=sub('_.*', '', x[1])
          x=sub('.*?_', '', x)
          paste(prot.acc, grep( toupper(mod.res), x, value=T), sep=';' )
          
        })
        
      }
      
      
      
    } # end if id.type == 'ph'

      ## ###################################################################
      ##   create single sites-centric reports
      ##
      ##
      ##redundant sites on multiply modified peptides---- 
      ## - Exclude sites on multiply phosphorylated peptides for which we
      ## - have also detected singly phosphorylated version
      n.sites <- sapply(all.sites, length)
      all.sites.mult <- all.sites[which(n.sites > 1)]
      all.sites.sing <- all.sites[which(n.sites == 1)]
      all.sites.mult <- lapply(all.sites.mult, function(x){
        rm.idx=which(x %in% unlist(all.sites.sing))
        if(length(rm.idx)>0)
          x=x[-rm.idx]
        
        x
      })
      all.sites.mult <- all.sites.mult[ sapply(all.sites.mult, length) > 0 ]
      ## all sites as list
      all.sites <- append(all.sites.mult, all.sites.sing)
      all.sites.unique <- unique(unlist(all.sites))
      
      sites.dup <- unlist(all.sites)[ duplicated( unlist(all.sites)) ]
      sites.nondup <- setdiff(all.sites.unique, sites.dup)
      
      #prepare site-centric table----
      mat.ss <- matrix(NA, nrow=length(all.sites.unique), ncol=ncol(mat), dimnames=list(all.sites.unique, cid))
      
      ## TODO: parallelize loop
      # map of row indices between site-centric and original table
      #cl <- makeCluster(detectCores()-1)
      #registerDoParallel(cl)
      #map.idx <-  foreach(x = rownames(mat.ss)) %dopar% {function(x) grep(paste(x, '($|\\")', sep=''), all.sites)}
      #on.exit(stopCluster(cl))
      map.idx <- lapply(rownames(mat.ss), function(x) names(all.sites)[grep(paste(x, '($|\\")', sep=''), all.sites)])
      names(map.idx) <- rownames(mat.ss)
      
      #combine expression of duplicated sites, e.g. sites detected on multiple versions of multiply phosphorylated peptides
      for(s in sites.dup){
        #cat(s, '\n')
        if(n == 1){
          mat.tmp <- matrix(mat[map.idx[[s]], ], ncol=n)
        } else{
          mat.tmp <- mat[map.idx[[s]], ]
        }
        mat.ss[s, ] <- apply(mat.tmp, 2, eval(parse(text=mode)), na.rm=T)
      }
      
      
      mat.ss[names(map.idx[sites.nondup]), ] <- data.matrix( mat[ unlist(map.idx[sites.nondup]), ] )
      
      #update GCT----
      ## - multiple sites (rids) have been combined.
      ## - pick single rid for combined sites
      idx <- sapply(map.idx, function(x)x[1])
      #rid.org <- rid
      #rdesc.org <- rdesc
      rid <- rid[ idx ]
      names(rid) <- names(map.idx)
      rdesc <- rdesc[idx, ]
      VMsitesAll <- sapply(map.idx, function(x) paste(names(all.sites)[x], collapse='|'))
      rdesc <- data.frame(rdesc, VMsitesAll)
      
      #create site ids-----
      ptm.site.ids <- paste(names(map.idx), mod.type, sep=ifelse(length(grep('^-', mod.type)) > 0, '','-'))
      

    ##rid <- ptm.site.ids
    rownames(mat.ss) <- rownames(rdesc) <- rid <- ptm.site.ids
    #export GCT
    gct@mat <- mat.ss
    gct@rid <- rid
    gct@cid <- cid
    gct@cdesc <- cdesc
    gct@rdesc <- rdesc
   
  } ## end if level=='ssc'
  
  ## ###################################
  ## export GCT

  ## filename
  fn <- sub('.*/', '', gct.str)
  
  ## site-report?
  sr <- level %in% c('ssc', 'gcr')
  glue.str <- "_{level}-{ifelse(sr,id.type.out, '')}{ifelse(sr, ifelse(loc,'_loc',''), '') }"
  if(appenddim){
      if(length(grep('_n[0-9]*x[0-9]*\\.gct$', fn)) > 0){
        fn <- paste0(sub('_n[0-9]*x[0-9]*\\.gct$', glue(glue.str), fn ))
      } else {
        fn <- paste0(sub('\\.gct$', glue(glue.str), fn ) )
      }
  } else {
    fn <-  paste0(sub('\\.gct$', glue(glue.str, '.gct'), sub('.*/', '', gct.str)) )
    }
  fn <- gsub('-\\.', '.', fn) %>% gsub('-$', '', .)
  
  ## export
  write.gct(gct, ofile = fn, appenddim = appenddim)
  
  return(fn)
}


## ########################################################################
## create UniProt-centric accesion numbers
## -map RefSeq accessions or gene symbol to UniProt accession
RefSeq2UniProt <- function(ids,                          ## character vector of accessions
                           n.try=10,                     ## maximal number of accessions to test in order to determine the source organism
                           keytype=c('REFSEQ', 'SYMBOL') ## RefSeq or gene symbols in 'ids'  
                           ){
  
  require(pacman)
  p_load(RSQLite)
  p_load(org.Hs.eg.db)
  p_load(org.Mm.eg.db)
  p_load(org.Rn.eg.db)
  p_load(org.Dr.eg.db)
  
  ## ###################################
  ##           id type
  ## ###################################
  keytype <- match.arg(keytype)
  
  ## ###################################
  ##        extract query strings
  ## ###################################
  id.query <- sub('(\\.|;).*', '', ids) ## first id
  names(id.query) <- ids
  
  ## ###################################
  ##          determine organism
  ## ###################################
  orgtype <- 'UNKNOWN'
  
  # try human 
  if(orgtype == 'UNKNOWN'){ 
    id.map.tmp <- try( mapIds(org.Hs.eg.db, keys=id.query[ sample(1:length(id.query), n.try)] , column=c('UNIPROT'), keytype=keytype, multiVals='first') )
    if(class(id.map.tmp) != 'try-error'){
      orgtype='HSA'
    }
  }
  # try mouse
  if(orgtype == 'UNKNOWN'){ 
    id.map.tmp <- try( mapIds(org.Mm.eg.db, keys=id.query[ sample(1:length(id.query), n.try)] , column=c('UNIPROT'), keytype=keytype, multiVals='first') )
    if(class(id.map.tmp) != 'try-error'){
      orgtype='MMU'
    }
  }
  # try rat
  if(orgtype == 'UNKNOWN'){ 
    id.map.tmp <- try( mapIds(org.Rn.eg.db, keys=id.query[ sample(1:length(id.query), n.try)] , column=c('UNIPROT'), keytype=keytype, multiVals='first') )
    if(class(id.map.tmp) != 'try-error'){
      orgtype='RNO'
    }
  }
  # try zebrafish
  if(orgtype == 'UNKNOWN'){ 
    id.map.tmp <- try( mapIds(org.Dr.eg.db, keys=id.query[ sample(1:length(id.query), n.try)] , column=c('UNIPROT'), keytype=keytype, multiVals='first') )
    if(class(id.map.tmp) != 'try-error'){
      orgtype='DRE'
    }
  }
  
  ## ##################################
  ## map
  if( orgtype != 'UNKNOWN'){
    if(orgtype == 'HSA')
      id.map.tmp <- try(mapIds(org.Hs.eg.db, keys=id.query , column=c('UNIPROT'), keytype=keytype, multiVals='first'))
    if(orgtype == 'MMU')
      id.map.tmp <- try(mapIds(org.Mm.eg.db, keys=id.query , column=c('UNIPROT'), keytype=keytype, multiVals='first'))
    if(orgtype == 'RNO')
      id.map.tmp <- try(mapIds(org.Rn.eg.db, keys=id.query , column=c('UNIPROT'), keytype=keytype, multiVals='first'))
    if(orgtype == 'DRE')
      id.map.tmp <- try(mapIds(org.Dr.eg.db, keys=id.query , column=c('UNIPROT'), keytype=keytype, multiVals='first'))
  } else {
    id.map.tmp <- c()
  }
  
  if(class(id.map.tmp) == 'try-error' | is.null( class(id.map.tmp) ) | class(id.map.tmp) == 'NULL' ){
    
    id.map <- data.frame(id=names(id.query), id.query=id.query, id.mapped=names(id.query), id.concat=ids, stringsAsFactors=F)

    keytype <- 'UNKNOWN'
    
  } else {
    
    #id.map.tmp[which(is.na(id.map.tmp))] <- 'NotFound'
    id.map <- data.frame(id=names(id.query), id.query=id.query, id.mapped=id.map.tmp, id.concat=paste(ids, id.map.tmp, sep='_'), stringsAsFactors=F)
  }
  
  ## results
  res <- list()
  res[[1]] <- keytype
  res[[2]] <- id.map
  res[[3]] <- orgtype
  names(res) <- c('keytype', 'id.map', 'orgtype')
  
  return(res)
}

## ##########################################################################
## function to convert an output file from SAM-based marker selection
## into a GCT 1.3 file as input for PTM-SEA
prepare_sam_output <- function( csv.str,  ## path to input csv
                                expr='^(contrast-|Fold Change)',
                                ofile=sub('\\.csv', '\\.gct', sub('.*/','', csv.str))
){
  require(pacman)
  p_load(glue)
  
  ## import
  csv <- read_csv(csv.str) %>% as.data.frame
  
  expr.idx <- grep(expr, colnames(csv))
  
  if(length(expr.idx) == 0) stop(glue('\n\nNo columns matching "{expr}" found in header of input file {csv.str}.\n\n'))
  
  
  mat <- csv[, expr.idx]  
  cid <- colnames(csv)[expr.idx]
  rdesc <- csv[, setdiff( colnames(csv), cid)]
  rid <- csv[, 1] 
  
  ## assemble GCT
  gct <- new('GCT')
  gct@mat <- data.matrix(mat)
  gct@rdesc <- rdesc
  gct@rid <- rid
  gct@cid <- cid
  
  fn <- sub('.*/', '', csv.str) %>% sub('\\.csv', '\\.gct', .)
  
  write.gct(gct, ofile = ofile, appenddim = F)
  
  return(0)
}

## ###########################################################################
## prepare nmf results for PTM-SEA
prepare_mo_nmf_output <- function(w.str, 
                                  type=c('pSTY', 'Prot'),
                                  id.column='geneSymbol',
                                  ofile='out'){
  library(pacman)
  p_load(glue)
  
  type <- match.arg(type)
  
  
  ## import w
  w.gct <- parse.gctx(w.str)
  w <- w.gct@mat
  rdesc <- w.gct@rdesc
  
  if( !id.column %in% colnames(rdesc ))
    stop(glue("Column '{id.column}' not found in!!"))
    
  
  ## extract p-sites/proteins
  idx <- which(rdesc$Type == type)

  w <- w[idx, ]
  rdesc <- rdesc[idx, ]
  rdesc <- data.frame(rdesc, id.nmf=rownames(w))
  
  cdesc <- data.frame(Dummy=rep('NMF.cluster', ncol(w)), Dummy2=rep('NMF.cluster', ncol(w)))
  rownames(cdesc) <- colnames(w)
  
  #rownames(w) <- sub(glue("^{type}-"), '', rownames(w))
  ## check whether 'id.column' contains unique entries
  ids <- rdesc[, id.column] %>% gsub(' ', '', .) %>% sub(glue("^{type}-"), '', .)
  
  if(sum(duplicated(ids)) > 0){
    w <-  aggregate(w, by=list(ids), FUN=function(x)x[which.max(abs(x))])
    rdesc <- aggregate(rdesc, by=list(ids), FUN=function(x) paste0(unique(x, collapse='|')))
    
    ids <- w[, 1]
    
    w <- w[, -c(1)]
    rdesc <- rdesc[, -c(1)]
    
  }
    
  rownames(w) <- rownames(rdesc) <- ids
  colnames(w) <- glue("cluster_{colnames(w)}")
  
  out <- new("GCT")
  out@mat <- data.matrix(w)
  out@rid <- rownames(w)
  out@cid <- colnames(w)
  out@rdesc <- rdesc
  out@cdesc <- cdesc
  
  write.gct(out, ofile = ofile, appenddim = F)
  
  return(0)
}

## ###########################################################################
##               PTM-SEA / ssGSEA volcano plots
gg_volc <- function(output.prefix, 
                    fdr.max = 0.05, ## max. FDR
                    n.max = 5, ## maximal number of signatures to label each side of the volcano plots
                    ...  ## passed to ggsave
                    ){
    #fdr.max <- 0.05 
    #n.max <- 5 
    
    ## import ptm-sea results
    fn3 <- glue('{output.prefix}-combined.gct')
    ptm <- parse.gctx(fn3)
    mat <- ptm@mat
    cid <- ptm@cid
    rdesc <- ptm@rdesc
    rid <- ptm@rid
    
    
    ## loop over sample columns
    plot.list <- vector('list', length(cid))
    names(plot.list) <- cid
    
    for(s in cid){
      
      pval.tmp <- rdesc[ , glue("pvalue.{sub('^X','',make.names(s))}")]
      fdr.tmp <- rdesc[ , glue("fdr.pvalue.{sub('^X','',make.names(s))}")]
      ol.tmp <- rdesc[, glue("Signature.set.overlap.percent.{sub('^X','',make.names(s))}")]
      score.tmp <- mat[ , glue('{s}')]
      
      Enrichment.Score <- score.tmp
      P.Value <- -10*log(pval.tmp, 10)
      
      
      Significant <- rep('n', nrow(rdesc))
      sig.idx <- which(fdr.tmp < fdr.max) 
      if(length(sig.idx) > 0)
        Significant[sig.idx] <- 'y'
      
      ## used for ranking
      Rank <- P.Value * Enrichment.Score
      
      data.plot <- data.frame(Enrichment.Score,
                              P.Value,
                              Significant,
                              Signature=rid,
                              Overlap.Percent=ol.tmp,
                              Rank=Rank)
      
      xlim=max(abs(data.plot$Enrichment.Score))
      ymax=max(abs(data.plot$P.Value))
      
      data.sig.dn <- data.plot %>% 
        filter(Significant == 'y' & Enrichment.Score < 0) %>% 
        arrange(Rank) 
      if(nrow(data.sig.dn) > n.max)
        data.sig.dn <- data.sig.dn[1:(min( n.max, nrow(data.sig.dn))), ]
        #data.sig.dn <- data.sig.dn %>% slice(1:(min( n.max, nrow(data.sig.dn))))
      
      data.sig.up <- data.plot %>% 
        filter(Significant == 'y' & Enrichment.Score > 0) %>% 
        arrange(desc(Rank)) 
      if(nrow(data.sig.up) > n.max)
        data.sig.up <- data.sig.up[1:(min( n.max, nrow(data.sig.up))), ]
      
      #  data.sig.up <- data.sig.up %>% slice(1:(min( n.max, nrow(data.sig.up))))
      
      
      p <- ggplot(data.plot, aes(Enrichment.Score, P.Value ) ) + 
        geom_point(aes(size=Overlap.Percent, colour=Significant)) + 
        xlim(-xlim, xlim) +
        geom_vline(xintercept=0, linetype=3) +
        labs(title=glue('{s}'), y='-10log10(P-value)') +
        
        geom_label_repel( aes(label=Signature),
                          #nudge_x=data.sig.dn$Enrichment.Score,
                          nudge_x=-5,
                          #nudge_y=seq(max(data.plot$P.Value), min(data.plot$P.Value), length.out = nrow(data.sig.dn) )[order(data.sig.dn$P.Value, decreasing = T)],
                          nudge_y=-5,
                          direction='y',
                          data=data.sig.dn,
                          force=1, size=3) +
        
        geom_label_repel( aes(label=Signature),
                          #nudge_x=data.sig.up$Enrichment.Score,
                          nudge_x=5,
                          nudge_y=-5,
                          direction='y',
                          data=data.sig.up,
                          force=1, size=3)
      
      p <- p + theme_bw() + theme(plot.title=element_text(hjust=0.5))
      
      
      plot.list[[s]] <- p
    }
    
    ## plot and save
    pp <- ggarrange(plotlist= plot.list, common.legend=T)
    annotate_figure(pp, top=glue("class vector: {output.prefix}"))
    ggsave(glue("volcano_{output.prefix}.pdf"), device='pdf', ...)
    
    return(0)
}

## ######################################################
## pathway heatmap
## - developed for GSEA/PTM-SEA on NMF results
pw_hm <- function(output.prefix, 
                  fdr.max = 0.05, ## max. FDR
                  n.max = 10, ## maximal number of signatures to label each side of the volcano plots
                  ptmsigdb=T,
                  ...  ## passed to pheatmap
){
  library(pacman)
  p_load(RColorBrewer)
  p_load(pheatmap)
  #fdr.max <- 0.05 
  #n.max <- 5 
  
  ## import ptm-sea results
  fn3 <- glue('{output.prefix}-combined.gct')
  ptm <- parse.gctx(fn3)
  mat <- ptm@mat
  cid <- ptm@cid
  rdesc <- ptm@rdesc
  rid <- ptm@rid
  
  ## helper function
  plothm <- function(rdesc, mat, fdr.max, n.max, fn.out){
    
    ## fdr
    fdr <- rdesc[,grep('^fdr.pvalue', colnames(rdesc))]
    keep.idx <- c()
    for(i in 1:ncol(fdr)){
      f <- fdr[, i] ## fdr
      s <- mat[, i] ## score
      idx=which(f < fdr.max)
      if(length(idx) > 0)
        keep.idx <- union(keep.idx, idx[order(abs(s[idx]), decreasing = T)[1:min(n.max, length(idx))]])
      #keep.idx <- union(keep.idx, idx)
    }
    
    fdr.filt <- fdr[keep.idx, ]
    mat.filt <- mat[keep.idx, ]
    
    dist.row <- dist(mat.filt, method = 'euclidean')
    
    mat.filt[fdr.filt > fdr.max] <- NA
    
    max.val = ceiling( max( abs(mat.filt), na.rm=T) )
    min.val = -max.val
    
    color.breaks = seq( min.val, max.val, length.out=12 )
    color.hm = rev(brewer.pal (length(color.breaks)-1, "RdBu"))
    
    try(pheatmap(mat.filt, 
                 cluster_cols = F, 
                 cluster_rows=T, 
                 clustering_distance_rows = dist.row, col=color.hm, 
                 breaks = color.breaks, filename = fn.out, ...))
  
  }
  #debug(plothm)
  if(ptmsigdb){ ## split categories
    rid.type <- sub('^(.*?)-.*', '\\1', rid) %>% unique  
    for(rt in rid.type){
      fn.out=glue("heatmap_{rt}_max.fdr_{fdr.max}_n.max_{n.max}.pdf")  
      idx <- grep(glue("^{rt}"), rid)
      plothm(rdesc[idx, ], mat[idx, ], fdr.max, n.max, fn.out)
    }
  } else {
    fn.out=glue("heatmap_max.fdr_{fdr.max}_n.max_{n.max}.pdf")  
    plothm(rdesc, mat, fdr.max, n.max, fn.out)
  }

}
