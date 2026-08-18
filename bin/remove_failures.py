#!/usr/bin/env python3

import argparse
import pandas as pd
import csv

##Given a summary file from GRiPHin produces a txt file with the samples listed that need to be removed. 
##Usage: >python create_samplesheet.py -s phx_output_GRiPHIn_Summary.tsv
## Written by Jill Hagey (qpk9@cdc.gov)

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Script that will review a griphin summary and will identify samples that have failed QC and need to be removed.")
    parser.add_argument("-s", "--summary", default=None, required=False, dest="summary", help="Summary files from Griphin.")
    parser.add_argument("-d", "--directory_samplesheet", default=None, required=False, dest="directory_samplesheet", help="Directory samplesheet from Griphin.")
    parser.add_argument('--by_st', dest="by_st", default=False, action='store_true', help='If by ST was passed then supress it if there is only one ST per taxa as it would be redundant.')
    return parser.parse_args()

#set colors for warnings so they are seen
CRED = "\033[91m" + "\nWarning: "
CEND = "\033[0m"

def get_failures(summary):
    """create list of samples that failed the griphin summary"""
    df = pd.read_csv(summary, header=0, sep="\t", dtype="str")
    df_fails = df[df["Minimum_QC_Check"].str.contains("FAIL")]
    failed_id_list = df_fails["WGS_ID"].tolist()
    #write failed ids to text
    with open("failed_ids.txt", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(failed_id_list)
    return failed_id_list

def filter_dir_samplesheet(failed_id_list, directory_samplesheet):
    """remove samples that failed from directory samplesheet so they aren"t in the downstream analysis"""
    df = pd.read_csv(directory_samplesheet, header=0, sep=",", dtype="str")
    print(df)
    df = df[~df["sample"].isin(failed_id_list)] #remove failed samples
    if df.empty:
        raise ValueError("After removing failures there are no samples left. At least 3 passing isolates are needed for analysis.")
    df.to_csv("Directory_samplesheet_pass.csv", index=False)


def get_single_st_taxa(summary):
    """
    Checks if there is more than one Primary_MLST for each unique taxa in Final_Taxa_ID.
    For taxa that only have a single unique ST, returns/writes a list of '<Taxa>_<ST>' entries.
    """
    df = pd.read_csv(summary, header=0, sep="\t", dtype="str")
    # Drop rows missing taxa or MLST info so they don't pollute the grouping
    df_valid = df.dropna(subset=["Final_Taxa_ID", "Primary_MLST"])
    single_st_list = []
    # Group by taxa and check number of unique STs
    for taxa, group in df_valid.groupby("Final_Taxa_ID"):
        unique_sts = group["Primary_MLST"].unique()
        if len(unique_sts) == 1:
            taxa_clean = taxa.strip().replace(" ", "_")
            st_clean = unique_sts[0].strip()
            single_st_list.append(f"{taxa_clean}_{st_clean}")
    # Write to file so Nextflow can pick it up as a val
    with open("single_st_taxa.txt", "w", newline="") as f:
        for entry in single_st_list:
            f.write(f"{entry}\n")
    return single_st_list

def main():
    args = parseArgs()
    # If a directory is given then create a samplesheet from it if not use the samplesheet passed
    failed_id_list = get_failures(args.summary)
    filter_dir_samplesheet(failed_id_list,args.directory_samplesheet)
    if args.by_st:
        single_st_list = get_single_st_taxa(args.summary)
        if single_st_list:
            print(CRED + f"The following taxa have only one ST and will be suppressed as it is redundant: {', '.join(single_st_list)}" + CEND)
    else:
        # Ensure the file always exists so Nextflow's output block doesn't fail
        open("single_st_taxa.txt", "w").close()

if __name__ == "__main__":
    main()