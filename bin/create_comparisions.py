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
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def create_sample_sheets(samplesheet):
    """Create a samplesheet with the assemblies for each Seq Type. Also, creates samplesheet to run SNVPhyl for each Seq Type."""
    complete_list = []
    seq_type = "All_Isolates"
    with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet: # create a new sample sheet for each ST that can be used by snvphyl
        st_snv_samplesheet.write('sample,directory') #write the header
    df = pd.read_csv(samplesheet, sep=',', header=0)
    sample_list = df["sample"].tolist()
    for sample in sample_list: # for each sample that is part of the ST
        with open(samplesheet, 'r') as f: # read the orginal directory samplesheet
            for line in f:
                if (str(sample)+",") in line:
                    with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet: # this create a file with headers
                        st_snv_samplesheet.write("\n" + line.strip('\n'))
                    assembly = line.split(',')[1].strip() + "/assembly/" + str(sample) + ".filtered.scaffolds.fa.gz"
                    complete_list.append(assembly)
    with open(seq_type +"_samplesheet.csv", 'w') as new_samplesheet: # create a new sample sheet for each ST
        new_samplesheet.write("sample,seq_type,assembly_1,assembly_2") #write the header
        combinations = [(a, b) for idx, a in enumerate(complete_list) for b in complete_list[idx + 1:]]
        for combo in combinations:
            sample1 = combo[0].split('/')[-1].replace(".filtered.scaffolds.fa.gz","")
            sample2 = combo[1].split('/')[-1].replace(".filtered.scaffolds.fa.gz","")
            new_samplesheet.write("\n" + sample1 + "_" + sample2 + "," + seq_type + "," + str(combo[0]) + "," + str(combo[1]))

def main():
    args = parseArgs()
    create_sample_sheets(args.samplesheet) # go back to the samplesheet and keep only lines this matching samplenames

if __name__ == '__main__':
    main()
