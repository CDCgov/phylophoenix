#!/usr/bin/env python3

import pandas as pd
import argparse
import csv
import glob

## Written by Jill Hagey (qpk9@cdc.gov)

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='Script to generate a PhoeNix summary excel sheet.')
    parser.add_argument('-s', '--samplesheet', default=None, required=False, dest='samplesheet', help='GRiPHin samplesheet of sample,directory in csv format.')
    parser.add_argument('-g', '--griphin_report', required=False, dest='griphin_report', help='A griphin excel report.')
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def get_st_groups(griphin_report):
    """Get unique ST groups from griphin report."""
    df = pd.read_excel(griphin_report, header=1)
    df.dropna(subset=['Primary_MLST'], inplace=True) #drop rows where there is na in the MLST column
    clean_df = df[~df.Primary_MLST.str.contains("-")] #remove samples that do not have MLST
    novel_df = clean_df[clean_df["Primary_MLST"].str.contains("Novel_allele")] # if there is novel allele in the primary mlst column separate them out
    indexes_to_drop = list(novel_df.index) # get indexes that have "Novel_allele" in "Primary_MLST" column
    clean_df = clean_df.drop(index=indexes_to_drop) # drop the rows that have "Novel_allele" in "Primary_MLST" column
    list_of_sts = clean_df["Primary_MLST"].unique() # get unique mlsts from what is left
    if list_of_sts.size == 0:  # This will be True if list_of_sts is empty
        raise ValueError("After removing Novel MLSTs there are no STs with enough isolates (min 3) to run Phylophoenix. This set can only be run all together.")
    #get sample names per st type into dictionary
    st_dict = {} #create an empty dictionary
    for seq_type in list_of_sts:
        sample_list = list(clean_df.loc[clean_df["Primary_MLST"] == seq_type, 'WGS_ID']) # get the sample names per ST type
        if len(sample_list) > 1: # Do not include cases where the there are more than 2 samples for a given ST type
            st_dict[seq_type] = sample_list # add st type and its samples to a dictionary
        else:
            pass
    return st_dict

def create_sample_sheets(st_dict, samplesheet):
    """Create a samplesheet with the assemblies for each Seq Type. Also, creates samplesheet to run SNVPhyl for each Seq Type."""
    complete_list = []
    for seq_type, sample_list in st_dict.items():
        list_of_samples_by_st = []
        with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet: # create a new sample sheet for each ST that can be used by snvphyl
            st_snv_samplesheet.write('sample,directory') #write the header
        for sample in sample_list: # for each sample that is part of the ST
            with open(samplesheet, 'r') as f: # read the orginal griphin samplesheet
                for line in f:
                    if (sample + ",") in line:
                        with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet: # this create a file with headers
                            st_snv_samplesheet.write("\n" + line.strip('\n'))
                        assembly = line.split(',')[1].strip() + "/assembly/" + sample + ".filtered.scaffolds.fa.gz"
                        list_of_samples_by_st.append(assembly)
                        complete_list.append(assembly)
        with open(seq_type +"_samplesheet.csv", 'w') as new_samplesheet: # create a new sample sheet for each ST
            new_samplesheet.write("sample,seq_type,assembly_1,assembly_2") #write the header
            seq_type_combinations = [(a, b) for idx, a in enumerate(list_of_samples_by_st) for b in list_of_samples_by_st[idx + 1:]]
            for combo in seq_type_combinations:
                sample1 = combo[0].split('/')[-1].replace(".filtered.scaffolds.fa.gz","")
                sample2 = combo[1].split('/')[-1].replace(".filtered.scaffolds.fa.gz","")
                new_samplesheet.write("\n" + sample1 + "_" + sample2 + "," + seq_type + "," + str(combo[0]) + "," + str(combo[1]))

def combine_samplesheets():
    files = glob.glob('ST*_samplesheet.csv')
    with open("All_Isolates_samplesheet.csv" , "w") as new_file:
        for f in files:
            with open(f, 'r') as opened_files:
                header = next(opened_files)
                for line in opened_files:
                    new_file.write(line)

def main():
    args = parseArgs()
    st_dict = get_st_groups(args.griphin_report) # open the excel sheet get sample names organized by their ST types
    create_sample_sheets(st_dict, args.samplesheet) # go back to the samplesheet and keep only lines this matching samplenames
    combine_samplesheets()

if __name__ == '__main__':
    main()
