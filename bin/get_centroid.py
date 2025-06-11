#!/usr/bin/env python3

import pandas as pd
import numpy as np
import argparse
import csv
import glob
import re

##Makes a new samplesheet for assemblies based on their st type. Expects that assemblies are in an output PHoeNIx folder
##Usage: >python get_reference_seq.py -s GRiPHin_samplesheet.csv -i sample1_sample2.tsv -t seq_type
## Written by Jill Hagey (qpk9@cdc.gov)

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='Script to return the full file path for the centroid assembly.')
    parser.add_argument('-i', '--input', required=True, dest='input', help='txt file that has mash distances on each line.')
    parser.add_argument('-s', '--samplesheet', required=True, dest='samplesheet', help='GRiPHin_samplesheet.csv.')
    parser.add_argument('-t', '--seq_type', required=True, dest='seq_type', help='sequence type.')
    return parser.parse_args()

def average_mash(input_mash_list, seq_type):
    """Takes in a cat list of mash distances and then makes a list with the average value for each entry"""
    #Read in tsv file as a pandas datafame
    mash_df = pd.read_csv(input_mash_list, sep='\t', names=["Reference_ID", "Query_ID", "Mash_distance", "P_value", "Matching_hashes"], index_col=False, dtype={'Mash_distance': np.float64, 'P_value': np.float64})
    #clean up sample names
    mash_df['Reference_ID'] = mash_df['Reference_ID'].str.replace(".filtered.scaffolds.fa.gz", "", regex=False)
    mash_df['Query_ID'] = mash_df['Query_ID'].str.replace(".filtered.scaffolds.fa.gz", "", regex=False)
    #Get unique sample names
    samples = mash_df['Query_ID'].unique()

    # Initialize variables to track the lowest mean and corresponding samples
    low_mean = float('inf')
    low_mean_samples = []

    #filter dataframe to only have one sample
    ##count = 0
    for sample in samples:
        filtered_df = mash_df.loc[(mash_df['Reference_ID'] == sample) | (mash_df['Query_ID'] == sample)]
        ave_dis = filtered_df['Mash_distance'].mean() #get average of distances

        # Update the list of samples with the lowest mean distance
        if ave_dis < low_mean:
            low_mean = ave_dis
            low_mean_samples = [sample]  # Reset the list with the new lowest sample
        elif ave_dis == low_mean:
            low_mean_samples.append(sample)  # Add to the list of samples with the same mean

    # Determine the appropriate output message based on the number of samples with the lowest mean
    if len(low_mean_samples) > 1:
        # If multiple samples share the same mean, choose the first one as the centroid
        message = (
            f"Two samples have the same mean distance: {low_mean_samples[0]} and {low_mean_samples[1]}\n"
            f"{low_mean_samples[0]} is set as the centroid for {seq_type}." )
    else:
        # If only one sample has the lowest mean, print the appropriate message
        message = f"{low_mean_samples[0]} is set as the centroid for {seq_type}."

    # Write the message to the output file
    output_filename = seq_type +"_centroid_info.txt"
    with open(output_filename, "w") as output_file:
        output_file.write(message)

    return low_mean_samples[0]  # Return the centroid sample name

    #    if count == 0: # initial setting of low_mean and sample
    #        low_mean = ave_dis
    #        low_mean_sample = sample
    #        count = count + 1 # turn this off
    #    elif ave_dis < low_mean: # set new low mean if the ave_dis for this sample is lower
    #        low_mean = ave_dis
    #        low_mean_sample = sample
    #    elif ave_dis == low_mean:
    #        print("Two samples have the same mean distance.")
    #with open(seq_type + "_centroid_info.txt", "w") as output:
    #    output.write(path_to_centroid)
    #return low_mean_sample

def get_assembly_path(seq_type,samplesheet,low_mean_sample):
    with open(samplesheet, "r") as sheet:
        header = next(sheet) #skip header
        for line in sheet:
            match = re.search(low_mean_sample, line)
            if match is not None:
                print(low_mean_sample)
                print(line.split(",")[1])
                path_to_centroid_dir = line.split(",")[1].strip("\n")
                if path_to_centroid_dir.endswith("/"):
                    path_to_centroid_dir.strip("/")
                path_to_centroid = path_to_centroid_dir + "/assembly/" + match[0] + ".filtered.scaffolds.fa.gz"
    with open("path_to_" + seq_type + "_centroid.csv", "w") as output:
        output.write(path_to_centroid)

def main():
    args = parseArgs()
    low_mean_sample = average_mash(args.input, args.seq_type) # open the excel sheet get sample names organized by their ST types
    get_assembly_path(args.seq_type, args.samplesheet, low_mean_sample)

if __name__ == '__main__':
    main()