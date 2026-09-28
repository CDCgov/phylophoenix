#!/usr/bin/env python3

import sys
sys.dont_write_bytecode = True
import pandas as pd
import argparse
import csv
import glob
from species_complexes import collapse_species_complex

## Written by Jill Hagey (qpk9@cdc.gov)

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Script to separate taxa by ST type.")
    parser.add_argument("-s", "--samplesheet", default=None, required=False, dest="samplesheet", help="GRiPHin samplesheet of sample,directory in csv format.")
    parser.add_argument("-g", "--griphin_report", required=False, dest="griphin_report", help="A griphin excel report.")
    parser.add_argument("-b", "--blind_list", default=None, required=False, dest="blind_list", help="CSV file with a list of sample_name,new_name. This option will output the new_name rather than the sample name to \"blind\" reports.")
    parser.add_argument("--use_secondary_mlst", default=False, action="store_true", required=False, dest="use_secondary_mlst", help="Use secondary MLST scheme.")
    parser.add_argument("--combine_complex", default=False, action="store_true", required=False, dest="combine_complex", help="Group species belonging to the same species complex (e.g. Citrobacter freundii complex) together instead of treating them as separate taxa.")
    parser.add_argument("--version", action="version", version=get_version())  # Add an argument to display the version
    return parser.parse_args()


def blind_map(control_file):
    """Creates a mapping dictionary between the old and new names"""
    rename_mapping = {}
    with open(control_file, "r") as controls:
        header = next(controls)  # skip the first line of the samplesheet
        for line in controls:
            old_sample_name = line.split(",")[0]
            new_sample_name = line.split(",")[1].rstrip("\n")
            if new_sample_name != "" and new_sample_name != old_sample_name:
                rename_mapping[new_sample_name] = old_sample_name
    return rename_mapping

def get_st_groups(griphin_report, use_secondary_mlst, combine_complex):
    """Get unique ST groups from griphin report. Returns a dict where keys are "<Final_Taxa_ID_with_underscores>_<Primary_MLST>" 
    and values are lists of WGS_IDs for groups that share the same Primary_MLST and Final_Taxa_ID and have at least 2 samples.
    """
    df = pd.read_excel(griphin_report, header=1)
    # Determine which MLST column to use
    if use_secondary_mlst:
        df_secondary = df.dropna(subset=["Secondary_MLST"])
        if len(df_secondary) == 0:
            print("No secondary MLST scheme found. Defaulting to primary MLST scheme.")
            mlst_col = "Primary_MLST"
        else:
            df = df_secondary
            mlst_col = "Secondary_MLST"
    else:
        mlst_col = "Primary_MLST"
    # Collapse species complex members into a single taxa label before grouping, so e.g. A. baumannii and A. pittii samples of the same ST are grouped together (same for the other complexes handled above).
    # Only done when --combine_complex is passed.
    df = df.copy()
    if combine_complex:
        df["Final_Taxa_ID"] = df["Final_Taxa_ID"].apply(collapse_species_complex)
    # remove rows that do not have a conventional ST (those containing "-")
    clean_df = df[~df[mlst_col].str.contains("-", na=False)]
    # remove Novel_allele rows
    novel_df = clean_df[clean_df[mlst_col].str.contains("Novel_allele", na=False)]
    if not novel_df.empty:
        clean_df = clean_df.drop(index=list(novel_df.index))
    list_of_sts = clean_df[mlst_col].unique()
    print(list_of_sts)
    if list_of_sts.size == 0:
        raise ValueError("After removing Novel MLSTs there are no STs with enough isolates (min 2) to run Phylophoenix. This set can only be run all together.")
    clean_df = clean_df.copy()
    clean_df.dropna(subset=["Final_Taxa_ID", "WGS_ID"], inplace=True)
    st_dict = {}
    grouped = clean_df.groupby([mlst_col, "Final_Taxa_ID"], observed=True)
    for (st, taxa), grp in grouped:
        if len(grp) > 1:
            taxa_clean = str(taxa).replace(" ", "_")
            key = f"{taxa_clean}_{st}"
            values = list(dict.fromkeys(grp["WGS_ID"].tolist()))
            st_dict[key] = values
    if not st_dict:
        raise ValueError("After removing Novel MLSTs there are no ST/taxa groups with at least 2 isolates (min 2) to run Phylophoenix. This set can only be run all together.")
    return st_dict

def create_sample_sheets(st_dict, samplesheet, blind_list):
    """Create a samplesheet with the assemblies for each Seq Type. Also, creates samplesheet to run SNVPhyl for each Seq Type."""
    complete_list = []
    if blind_list != None:
        rename_mapping = blind_map(blind_list)
    for seq_type, sample_list in st_dict.items():
        list_of_samples_by_st = []
        with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet:  # create a new sample sheet for each ST that can be used by snvphyl
            st_snv_samplesheet.write("sample,directory")  # write the header
        for sample in sample_list:  # for each sample that is part of the ST
            if blind_list != None and sample in rename_mapping.keys():  # if the sample is in the blind list change it to the old name to compare 
                sample = rename_mapping[sample]
            with open(samplesheet, "r") as f:  # read the orginal griphin samplesheet
                for line in f:
                    if (sample + ",") in line:
                        with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet:  # this create a file with headers
                            st_snv_samplesheet.write("\n" + line.strip("\n"))
                        assembly = line.split(",")[1].strip() + "/assembly/" + sample + ".filtered.scaffolds.fa.gz"
                        list_of_samples_by_st.append(assembly)
                        complete_list.append(assembly)
        with open(seq_type +"_samplesheet.csv", "w") as new_samplesheet:  # create a new sample sheet for each ST
            new_samplesheet.write("sample,seq_type,assembly_1,assembly_2")  # write the header
            seq_type_combinations = [(a, b) for idx, a in enumerate(list_of_samples_by_st) for b in list_of_samples_by_st[idx + 1:]]
            for combo in seq_type_combinations:
                sample1 = combo[0].split("/")[-1].replace(".filtered.scaffolds.fa.gz","")
                sample2 = combo[1].split("/")[-1].replace(".filtered.scaffolds.fa.gz","")
                new_samplesheet.write("\n" + sample1 + "_" + sample2 + "," + seq_type + "," + str(combo[0]) + "," + str(combo[1]))

def combine_samplesheets():
    files = glob.glob("ST*_samplesheet.csv")
    with open("All_Isolates_samplesheet.csv" , "w") as new_file:
        for f in files:
            with open(f, "r") as opened_files:
                header = next(opened_files)
                for line in opened_files:
                    new_file.write(line)

def main():
    args = parseArgs()
    st_dict = get_st_groups(args.griphin_report, args.use_secondary_mlst, args.combine_complex)  # open the excel sheet get sample names organized by their ST types
    create_sample_sheets(st_dict, args.samplesheet, args.blind_list)  # go back to the samplesheet and keep only lines this matching samplenames
    combine_samplesheets()

if __name__ == "__main__":
    main()