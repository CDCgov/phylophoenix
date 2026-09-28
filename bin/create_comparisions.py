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

ALL_ISOLATES_KEY = "All_Isolates"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Script to generate a PhoeNix summary excel sheet.")
    parser.add_argument("-s", "--samplesheet", default=None, required=False, dest="samplesheet", help="GRiPHin samplesheet of sample,directory in csv format.")
    parser.add_argument("-g", "--griphin", default=None, required=False, dest="griphin", help="GRiPHin file.")
    parser.add_argument("--combine_complex", default=False, action="store_true", required=False, dest="combine_complex", help="Group species belonging to the same species complex (e.g. Citrobacter freundii complex) together instead of treating them as separate taxa.")
    parser.add_argument('--by_all', default=False, action="store_true", required=False, dest='by_all', help='In addition to splitting samples by Final_Taxa_ID, also create one extra group containing all samples together regardless of species. Ignored if --no_species is passed.')
    parser.add_argument('--no_species', default=False, action="store_true", required=False, dest='no_species', help='Skip splitting samples by Final_Taxa_ID entirely. Only a single group containing all samples is created, regardless of species. Takes precedence over --by_all.')
    parser.add_argument("--version", action="version", version=get_version())# Add an argument to display the version
    return parser.parse_args()

def create_sample_sheets(samplesheet, taxa, sample_list):
    """Create a samplesheet with the assemblies for each Seq Type. Also, creates samplesheet to run SNVPhyl for each Seq Type."""
    complete_list = []
    seq_type = taxa if taxa == ALL_ISOLATES_KEY else "All_" + taxa + "_Isolates"
    with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet:  # create a new sample sheet for each ST that can be used by snvphyl
        st_snv_samplesheet.write("sample,directory")  # write the header
    df = pd.read_csv(samplesheet, sep=",", header=0, dtype="str")
    # sample_list = df["sample"].tolist()
    for sample in sample_list:  # for each sample that is part of the ST
        with open(samplesheet, "r") as f:  # read the orginal directory samplesheet
            for line in f:
                if (str(sample)+",") in line:
                    with open("SNVPhyl_" + seq_type +"_samplesheet_pre.csv", "a") as st_snv_samplesheet:  # this create a file with headers
                        st_snv_samplesheet.write("\n" + line.strip("\n"))
                    assembly = line.split(",")[1].strip() + "/assembly/" + str(sample) + ".filtered.scaffolds.fa.gz"
                    complete_list.append(assembly)
    with open(seq_type +"_samplesheet.csv", "w") as new_samplesheet:  # create a new sample sheet for each ST
        new_samplesheet.write("sample,taxa,seq_type,assembly_1,assembly_2")  # write the header
        combinations = [(a, b) for idx, a in enumerate(complete_list) for b in complete_list[idx + 1:]]
        for combo in combinations:
            sample1 = combo[0].split("/")[-1].replace(".filtered.scaffolds.fa.gz","")
            sample2 = combo[1].split("/")[-1].replace(".filtered.scaffolds.fa.gz","")
            new_samplesheet.write("\n" + sample1 + "_" + sample2 + "," + taxa + "," + seq_type + "," + str(combo[0]) + "," + str(combo[1]))

def get_taxa_samples(griphin, combine_complex, by_all, no_species):
    """Extract taxa groups and their corresponding sample lists from GRiPHin TSV file.

    If combine_complex is True, species belonging to a recognized species complex (see
    species_complexes.py) are grouped together under the complex name.

    If no_species is True, taxa splitting is skipped entirely -- the only group produced is
    a single "All_Isolates" group containing every sample in the report. combine_complex and
    by_all have no effect in this case, since there's only ever one group.

    If by_all is True (and no_species is False), the normal per-taxa groups are produced AND
    an additional "All_Isolates" group is added alongside them, so downstream comparisons run
    both the per-species splits and one comparison covering every sample together.
    """
    df = pd.read_csv(griphin, sep="\t", header=0, dtype="str")

    if no_species:
        # Skip taxa splitting entirely -- one group containing every sample in the report.
        return {ALL_ISOLATES_KEY: df["WGS_ID"].tolist()}

    # Collapse species complex members into their complex-level name BEFORE converting spaces to underscores (collapse_species_complex expects space-separated genus/species names).
    # Only done when --combine_complex is passed.
    if combine_complex:
        df["Final_Taxa_ID"] = df["Final_Taxa_ID"].apply(collapse_species_complex)
    df["Final_Taxa_ID"] = df["Final_Taxa_ID"].str.replace(" ", "_")  # Replace spaces with underscores in Final_Taxa_ID
    # Group samples by Final_Taxa_ID
    taxa_groups = {}
    for taxa in df["Final_Taxa_ID"].unique():
        # Get all samples for this taxa
        samples = df[df["Final_Taxa_ID"] == taxa]["WGS_ID"].tolist()
        taxa_groups[taxa] = samples

    if by_all:
        # Add an additional group covering every sample, on top of the per-taxa groups above.
        taxa_groups[ALL_ISOLATES_KEY] = df["WGS_ID"].tolist()

    return taxa_groups

def main():
    args = parseArgs()
    taxa_groups = get_taxa_samples(args.griphin, args.combine_complex, args.by_all, args.no_species)  # get the taxa and samples from the griphin file
    for taxa, sample_list in taxa_groups.items():
        create_sample_sheets(args.samplesheet, taxa, sample_list)  # go back to the samplesheet and keep only lines this matching samplenames

if __name__ == "__main__":
    main()