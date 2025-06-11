#!/usr/bin/env python3

import re
import sys
import argparse

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description='replace "reference" with the WGS_ID of reference squence.')
    parser.add_argument("-n", "--newick_file", dest='newick_file', required=False, help="Newick file tree file")
    parser.add_argument("-s", "--snp_matrix_file", dest='snp_matrix_file', required=True, help="snp matrix file TSV file")
    parser.add_argument("-m", "--metadata", dest='metadata', required=False, help="metadata file")
    parser.add_argument("-o", "--output", dest='output', required=False, help="output prefix")
    parser.add_argument("-c", "--centroid_info", dest='centroid_info_file', required=True, help="centroid_info_file.")
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def extract_centroid(centroid_file):
    """Extract the first word from any line containing 'is set as the centroid'."""
    with open(centroid_file, 'r') as f:
        for line in f:
            if "is set as the centroid" in line:
                return line.split()[0]  # First word in the line
    raise ValueError("No centroid information found in the file.")

def replace_reference_in_file(input_file, output_file, replacement):
    """Replace the word 'reference' with the replacement string in a file."""
    with open(input_file, 'r') as f:
        content = f.read()

    # Replace all occurrences of 'reference' with word boundaries
    modified_content = re.sub(r'\breference\b', replacement, content)

    with open(output_file, 'w') as f:
        f.write(modified_content)

def replace_reference_in_meta_file(input_file, output_file, centroid):
    """Replace the word 'reference' with the replacement string in a file."""
    with open(input_file, 'r') as f:
        content = f.read()
    # Replace all occurrences of 'reference' with word boundaries
    modified_content = re.sub(rf'\b{re.escape(centroid)}\b', centroid + "*", content)

    with open(output_file, 'w') as f:
        f.write(modified_content)

def replace_reference_in_snvfile(input_file, output_file, replacement):
    """Replace the word 'reference' with the replacement string in a file."""
    with open(input_file, 'r') as f:
        content = f.readlines()

    # Process each line to replace words and remove trailing tabs
    modified_content = []
    for line in content:
        # Replace 'strain' with 'WGS_ID' and 'reference' with the replacement string
        line = re.sub(r'\bstrain\b', "WGS_ID", line)
        line = re.sub(r'\breference\b', replacement, line)

        # Remove any trailing tab and add the cleaned line to the modified content
        modified_content.append(line.rstrip('\t\n') + '\n')

    # Write the modified content to the output file
    with open(output_file, 'w') as f:
        f.writelines(modified_content)

def main(newick_file, snp_matrix_file, centroid_info_file, output_prefix, metadata):
    # Step 1: Extract the centroid string
    try:
        centroid = extract_centroid(centroid_info_file)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    replacement_string = f"{centroid}*"
    replacement_string_tree = f"{centroid}"

    # Replace 'reference' in the Newick file
    if newick_file !=None:
        replace_reference_in_file(newick_file, output_prefix + "_SNVPhyl.newick", replacement_string_tree)

    # Replace 'reference' in the metadata
    if metadata !=None:
        replace_reference_in_meta_file(metadata, output_prefix + "_cleaned_metadata.tsv", centroid)

    # Replace 'reference' in the SNP matrix file
    replace_reference_in_snvfile(snp_matrix_file, output_prefix + "_snvMatrix.tsv", replacement_string)

    print(f"Modifications complete. Modified files saved as '{newick_file}' and '{snp_matrix_file}.modified'.")

if __name__ == "__main__":
    args = parseArgs()
    main(args.newick_file, args.snp_matrix_file, args.centroid_info_file, args.output, args.metadata)
