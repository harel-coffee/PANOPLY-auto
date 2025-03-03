#!/bin/bash
#
# Copyright (c) 2020 The Broad Institute, Inc. All rights reserved.
#

echo -e "\n---------------------------"
echo -e "Creating, uploading, linking-"
echo -e "sample set aggregates -------"
echo -e "---------------------------\n"

source config.sh
source $src/tedmint-lib.sh

mkdir -p aggregates
Rscript --verbose $src/r-source/create-aggregates.r \
  -a $csv_types \
  -b $gct_types

echo -e "Done.."

Rscript --verbose $src/r-source/attribute-sample-set.r \
  -a $bucket \
  -b $wkspace \
  -c $project \
  -d $csv_types \
  -e $gct_types
