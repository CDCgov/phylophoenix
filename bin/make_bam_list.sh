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
for f in *_sorted.bam; do
    ((count++))
    if [[ count == 1 ]]; then 
        echo "--bam bam$count=./$f " | tr -d "\n" > bam_line.txt
    else
        echo "--bam bam$count=./$f " | tr -d "\n" >> bam_line.txt
    fi
done