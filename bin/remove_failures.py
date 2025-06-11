#!/usr/bin/env python3

import argparse
import pandas as pd
import csv

##Given a summary file from GRiPHin produces a txt file with the samples listed that need to be removed. 
##Usage: >python create_samplesheet.py -s phx_output_GRiPHIn_Summary.tsv
## Written by Jill Hagey (qpk9@cdc.gov)

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='Script that will review a griphin summary and will identify samples that have failed QC and need to be removed.')
    parser.add_argument('-s', '--summary', default=None, required=False, dest='summary', help='Summary files from Griphin.')
    parser.add_argument('-d', '--directory_samplesheet', default=None, required=False, dest='directory_samplesheet', help='Directory samplesheet from Griphin.')
    return parser.parse_args()

#set colors for warnings so they are seen
CRED = '\033[91m'+'\nWarning: '
CEND = '\033[0m'

def get_failures(summary):
    '''create list of samples that failed the griphin summary'''
    df = pd.read_csv(summary, header=0, sep='\t')
    df_fails = df[df['Minimum_QC_Check'].str.contains('FAIL')]
    failed_id_list = df_fails["WGS_ID"].tolist()
    #write failed ids to text
    with open("failed_ids.txt", "w", newline='') as f:
        writer = csv.writer(f)
        writer.writerow(failed_id_list)
    return failed_id_list

def filter_dir_samplesheet(failed_id_list, directory_samplesheet):
    '''remove samples that failed from directory samplesheet so they aren't in the downstream analysis'''
    df = pd.read_csv(directory_samplesheet, header=0, sep=',')
    df = df[~df['sample'].isin(failed_id_list)] #remove failed samples
    if df.empty:
        raise ValueError("After removing failures there are no samples left. At least 3 passing isolates are needed for analysis.")
    df.to_csv('Directory_samplesheet.csv', index=False)

def main():
    args = parseArgs()
    # If a directory is given then create a samplesheet from it if not use the samplesheet passed
    failed_id_list = get_failures(args.summary)
    filter_dir_samplesheet(failed_id_list,args.directory_samplesheet)

if __name__ == '__main__':
    main()