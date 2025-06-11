#!/bin/bash -l

#
# Description: create bam_list.txt file for process downstream
#
# Modules required: None
#
# V1.0 (09/11/2023)
#
# Created by Jill Hagey (qpk9@cdc.gov)
#

count=0
for f in *_consolidated.bcf; do
    ((count++))
    fname=$(basename $f _consolidated.bcf)
    if [[ count == 1 ]]; then 
        echo "--consolidate_vcf $fname=$f " | tr -d "\n" > consolidation_line.txt
    else
        echo "--consolidate_vcf $fname=$f " | tr -d "\n" >> consolidation_line.txt
    fi
done