#!/usr/bin/env python3

import sys
import glob
import os
import argparse
import re
import csv

from decimal import *
import pandas as pd
import numpy as np
import json
import xlsxwriter as ws
from xlsxwriter.utility import xl_rowcol_to_cell
from Bio import SeqIO


##Makes a summary Excel file when given a series of output summary line files from PhoeNiX
##Usage: >python convert_samplesheet.py -s samplesheet.csv -c control_file.csv -o output
## Written by Jill Hagey (qpk9@cdc.gov)

#set colors for warnings so they are seen
CRED = '\033[91m'+'\nWarning: '
CEND = '\033[0m'

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='Script to generate a PhoeNix summary excel sheet.')
    parser.add_argument('-s', '--samplesheet', default=None, required=False, dest='samplesheet', help='PHoeNIx style samplesheet of sample,directory in csv format. Directory is expected to have PHoeNIx stype output.')
    parser.add_argument('-d', '--directory', default=None, required=False, dest='directory', help='If a directory is given rather than samplesheet GRiPHin will create one for all samples in the directory.')
    parser.add_argument('-t', '--seq_type', required=True, dest='seq_type', help='Sequence Type.')
    parser.add_argument('-o', '--output', default="GRiPHin_Report", required=False, dest='output', help='Name of output file.')
    return parser.parse_args()

def convert_samplesheet(samplesheet, seq_type):
    '''This function takes from griphen that has a directory and converts it to output a samplesheet with the trimmed reads out of phoenix'''
    count = 1 # set count
    sample_count = len(open(samplesheet).readlines())-1 # get total number of samples
    with open(samplesheet, 'r') as f:
        header = f.readline()
        with open("updated_samplesheet.csv", "w") as new_samplesheet:
            new_samplesheet.write('sample,fastq_1,fastq_2,seq_type\n')
            for line in f:
                sample_name = str(line.split(",")[0]) # get sample name
                sample_path =str(line.split(",")[1]) # get directory
                # check if there is a trailing / and if doesn't have one add it
                if line[-1] != "/":
                    line = line + "/"
                sample_path = sample_path.strip("\n")
                # Get R1/R2 lines
                R1_line = sample_path + "/fastp_trimd/" + sample_name + "_1.trim.fastq.gz"
                R2_line = sample_path + "/fastp_trimd/" + sample_name + "_2.trim.fastq.gz"
                if count < sample_count:
                    full_line = sample_name + "," + R1_line + "," + R2_line + "," + seq_type + "\n"
                elif count == sample_count:
                    full_line = sample_name + "," + R1_line + "," + R2_line + "," + seq_type
                new_samplesheet.write(full_line)
                count = count + 1
    return new_samplesheet

def directory_to_samplesheet(directory): # not tested.
    """Function will create a samplesheet from samples in a directory if -d argument passed."""
    #directory = os.path.abspath(directory) # make sure we have an absolute path to start with
    count = 1 # set count
    with open("updated_samplesheet.csv", "w") as samplesheet:
        samplesheet.write('sample,fastq_1,fastq_2,seq_type\n')
    dirs = os.listdir(directory)
    # If there are any new files added to the top directory they will need to be added here or you will get an error
    skip_list_a = glob.glob(directory + "/*_GRiPHin_Summary.*") # for if griphin is run on a folder that already has a report in it
    skip_list_a = [ gene.split('/')[-1] for gene in skip_list_a ]  # just get the excel name not the full path
    skip_list_b = ["BiosampleAttributes_Microbe.1.0.xlsx", "Sra_Microbe.1.0.xlsx", "Phoenix_Summary.tsv", "pipeline_info", "GRiPHin_Summary.xlsx", "GRiPHin_Summary.tsv", "multiqc", "samplesheet_converted.csv", "Directory_samplesheet.csv", "sra_samplesheet.csv"]
    skip_list = skip_list_a + skip_list_b
    sample_count = len(dirs) # get total number of samples
    for sample in dirs:
        if sample not in skip_list:
            with open("updated_samplesheet.csv", "a") as samplesheet:
                if directory[-1] != "/": # if directory doesn't have trailing / add one
                    directory = directory + "/"
                sample_path = sample_path.strip("\n")
                # Get R1/R2 lines
                R1_line = sample_path + "/fastp_trimd/" + sample + "_1.trim.fastq.gz"
                R2_line = sample_path + "/fastp_trimd/" + sample + "_2.trim.fastq.gz"
                if count < sample_count:
                    full_line = sample + "," + R1_line + "," + R2_line + "\n"
                elif count == sample_count:
                    full_line = sample + "," + R1_line + "," + R2_line
                samplesheet.write(full_line)
                count = count + 1
    return samplesheet

def main():
    args = parseArgs()
    # If a directory is given then create a samplesheet from it if not use the samplesheet passed
    if args.directory !=None:
        directory_to_samplesheet(args.directory)
    elif args.samplesheet !=None:
        convert_samplesheet(args.samplesheet, args.seq_type)
    else:
        sys.exit(CRED + "You MUST pass a directory of PHoeNIx output to create a samlesheet.\n" + CEND)

if __name__ == '__main__':
    main()