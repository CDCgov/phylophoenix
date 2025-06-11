#!/usr/bin/env python3

import os
import argparse

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='replace "reference" with the WGS_ID of reference squence.')
    parser.add_argument("-s", "--samplesheet", dest='samplesheet',required=True, help="st_snv_samplesheets")
    parser.add_argument("-r", "--reference_name", dest='reference_name',required=True, help="meta.seq_type")
    parser.add_argument("-o", "--output", dest='output',required=False, help="output prefix")
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def remove_lines_starting_with(samplesheet, output, ref_name):
    # Open the original file for reading and the temporary file for writing
    with open(samplesheet, 'r') as infile, open(output, 'w') as outfile:
        for line in infile:
            # Write the line to outfile only if it doesn't start with ref_name
            if not line.startswith(ref_name):
                outfile.write(line)

def main(samplesheet, output, ref_name):
    remove_lines_starting_with(samplesheet, output, ref_name)

if __name__ == "__main__":
    args = parseArgs()
    output = "SNVPhyl_" + args.output + "_samplesheet.csv"
    main(args.samplesheet, output, args.reference_name)

