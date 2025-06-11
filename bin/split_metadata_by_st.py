#!/usr/bin/env python3

import re
import argparse
import pandas as pd
import csv

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='Script to generate a PhoeNix summary excel sheet.')
    parser.add_argument("-s", "--st_snv_samplesheets", dest='st_snv_samplesheets', required=True, help="st_snv_samplesheets file created in pipeline")
    parser.add_argument("-m", "--metadata", dest='metadata', required=True, help="metadata file passed by user.")
    parser.add_argument("--seq_type", dest='seq_type', required=True, help="output prefix")
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def get_ids_if_content_beyond_header(metadata):
    ids = []
    with open(metadata, 'r') as file:
        reader = csv.reader(file, delimiter='\t')  # Specify delimiter for TSV
        header = next(reader)  # Read and skip the header line
        # Try reading the first data line
        try:
            first_data_line = next(reader)
            # If there's no actual content beyond header, raise the error
            if not first_data_line:
                raise ValueError("The metadata file is empty.")
            # Otherwise, store the ID from the first data line
            ids.append(first_data_line[0])
        except StopIteration:
            raise ValueError("The metadata file is empty.")
        
        # Continue reading the rest of the file to get all IDs in the first column
        for row in reader:
            if row:  # Check if row is not empty
                ids.append(row[0])
    return ids

def verify_ids_in_metadata(ids, ids_to_keep):
    # Find missing IDs in the metadata file
    missing_ids = set(ids_to_keep) - set(ids)
    # Check if there are any missing IDs
    if missing_ids:
        print(f"The following IDs are missing in the metadata file: {missing_ids}")
        raise ValueError("Metadata file is missing required IDs. PhyloPHoeNIx expects all samples to be in the metadata file, leave cells blank if there is no data for them, but include the WGS_ID in the first column.")

def split_metadata_by_st(metadata, st_snv_samplesheets, seq_type):
    # Extract seq_type from the filename using regex
    match = re.search(r'_(.*?)_', st_snv_samplesheets)

    # Check if there is data in the metadata file and collect ids if present
    ids_in_meta = get_ids_if_content_beyond_header(metadata)

    # Collect the WGS_IDs from the first file
    ids_to_keep = []
    with open(st_snv_samplesheets, 'r') as reader:
        next(reader)  # Skip the first line (header)
        for line in reader:
            columns = line.strip().split(',')
            if columns:
                ids_to_keep.append(columns[0].strip())  # Collect the first column

    # Check that all ids to keep are in the metadata file. 
    verify_ids_in_metadata(ids_in_meta, ids_to_keep)

    # Filter the metadata file to keep only the relevant rows
    with open(metadata, 'r') as reader:
        lines = reader.readlines()  # Read all lines
        header = lines[0]
        filtered_lines = [header]  # Initialize with the header

        for line in lines[1:]:  # Process remaining lines
            meta_columns = line.strip().split('\t')[0]
            if meta_columns in ids_to_keep:
                filtered_lines.append(line)

    # Check if the filtered result contains more than just the header
    #if len(filtered_lines) <= 1:
    #    raise ValueError(f"The metadata file is empty or contains only headers. PhyloPHoeNIx expects all samples to be in the metadata file, leave cells blank if there is no data for them, but include the WGS_ID in the first column.")

    # Rewrite the original metadata file with the filtered content
    with open(seq_type + "_metadata.tsv", 'w') as writer:
        writer.writelines(filtered_lines)

def quality_check(samplesheet, metadata, seq_type):
    # Load metadata and samplesheet files
    samplesheet = pd.read_csv(samplesheet, sep=',')

    # Extract sample from the samplesheet file
    samplesheet_wgs_ids = samplesheet['sample'].tolist()

    # Load metadata files
    metadata = pd.read_csv(metadata, sep='\t')
    # Double-check that the first column of metadata is named 'sample' if not then rename it
    first_column = metadata.columns[0]
    if first_column != 'sample':
        print(f"Renaming first column from '{first_column}' to 'sample'.")
        metadata.rename(columns={first_column: 'sample'}, inplace=True)

    # Find missing sample names (those in the samplesheet but not in metadata)
    metadata_wgs_ids = metadata['sample'].tolist()
    missing_ids = [wgs_id for wgs_id in samplesheet_wgs_ids if wgs_id not in metadata_wgs_ids]

    # If there are missing IDs, add them to the metadata with empty values
    if missing_ids:
        print(f"Adding {missing_ids} missing sample(s) to the metadata.")
        
        # Create a DataFrame with the missing IDs and NaN for all other columns
        missing_rows = pd.DataFrame(missing_ids, columns=['sample'])
        for col in metadata.columns[1:]:
            missing_rows[col] = pd.NA  # Fill the rest of the columns with NaN

        # Append the missing rows to the metadata
        metadata = pd.concat([metadata, missing_rows], ignore_index=True)
    return metadata

def main():
    args = parseArgs()
    updated_metadata = quality_check(args.st_snv_samplesheets, args.metadata, args.seq_type)
    # Save the updated metadata DataFrame back to a file (temporary or overwritten)
    updated_metadata_file = "updated_metadata.tsv"
    updated_metadata.to_csv(updated_metadata_file, sep='\t', index=False)
    #split metadata
    split_metadata_by_st(updated_metadata_file, args.st_snv_samplesheets, args.seq_type)

if __name__ == '__main__':
    main()

