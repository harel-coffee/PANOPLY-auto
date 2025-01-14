FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-r:2.1.9
USER root

RUN R -e 'install.packages(c("pacman", "optparse", "gtools", "verification", "doParallel", "foreach", "magrittr", "yaml", "glue", "dplyr", "tidyr"))'
RUN R -e 'BiocManager::install(c("rhdf5", "cmapR", "Biostrings"))'

RUN apt-get update && apt-get install -y dos2unix && apt-get install -y nano
RUN mkdir -p /ptm-sea/src
RUN mkdir -p /ptm-sea/db/ptmsigdb
RUN dos2unix /ptm-sea/src

RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/src/io.R && dos2unix io.R && mv io.R /ptm-sea/src
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/src/utils.R && dos2unix utils.R && mv utils.R /ptm-sea/src
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/src/ssGSEA2.0.R && dos2unix ssGSEA2.0.R && mv ssGSEA2.0.R /ptm-sea/src
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/src/preprocess_gct.R && dos2unix preprocess_gct.R && mv preprocess_gct.R /ptm-sea/src

# download PTM signature databases
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.flanking.human.v2.0.0.gmt && mv ptm.sig.db.all.flanking.human.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.flanking.mouse.v2.0.0.gmt && mv ptm.sig.db.all.flanking.mouse.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.flanking.rat.v2.0.0.gmt && mv ptm.sig.db.all.flanking.rat.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.sitegrpid.human.v2.0.0.gmt && mv ptm.sig.db.all.sitegrpid.human.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.sitegrpid.mouse.v2.0.0.gmt && mv ptm.sig.db.all.sitegrpid.mouse.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.sitegrpid.rat.v2.0.0.gmt && mv ptm.sig.db.all.sitegrpid.rat.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.uniprot.human.v2.0.0.gmt && mv ptm.sig.db.all.uniprot.human.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.uniprot.mouse.v2.0.0.gmt && mv ptm.sig.db.all.uniprot.mouse.v2.0.0.gmt /ptm-sea/db/ptmsigdb
RUN wget https://raw.githubusercontent.com/broadinstitute/ssGSEA2.0/master/db/ptmsigdb/ptm.sig.db.all.uniprot.rat.v2.0.0.gmt && mv ptm.sig.db.all.uniprot.rat.v2.0.0.gmt /ptm-sea/db/ptmsigdb

RUN chmod +x /ptm-sea/src/ssGSEA2.0.R
RUN chmod +x /ptm-sea/src/preprocess_gct.R

ADD terra-functions.R /ptm-sea/src/terra-functions.R

USER $USER
