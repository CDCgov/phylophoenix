#!/usr/bin/env python3

import sys
sys.dont_write_bytecode = True
import argparse
import pandas as pd
import csv
from species_complexes import collapse_species_complex

## Given a summary file from GRiPHin produces a txt file with the samples listed that need to be removed. 
## Usage: >remove_failures.py -s GRiPHin_Summary.tsv -d Directory_samplesheet_converted.csv --by_st
## Written by Jill Hagey (qpk9@cdc.gov)

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Script that will review a griphin summary and will identify samples that have failed QC and need to be removed.")
    parser.add_argument("-s", "--summary", default=None, required=False, dest="summary", help="Summary files from Griphin.")
    parser.add_argument("-d", "--directory_samplesheet", default=None, required=False, dest="directory_samplesheet", help="Directory samplesheet from Griphin.")
    parser.add_argument('--by_st', dest="by_st", default=False, action='store_true', help='If by ST was passed then supress it if there is only one ST per taxa as it would be redundant.')
    parser.add_argument('--use_secondary_mlst', dest="use_secondary_mlst", default=False, action='store_true', help='If set, group by Secondary_MLST instead of Primary_MLST when checking for redundant/low-count taxa-ST combinations. Must match the value passed to get_sequence_types.py so the redundancy check uses the same MLST scheme that by-ST grouping actually uses.')
    parser.add_argument('--combine_complex', dest="combine_complex", default=False, action='store_true', help='If set, group species belonging to the same species complex together before checking for redundant/low-count taxa-ST combinations. Must match the value passed to get_sequence_types.py so the two scripts agree on whether a taxon has one or multiple STs.')
    return parser.parse_args()

# set colors for warnings so they are seen
CRED = "\033[91m" + "\nWarning: "
CEND = "\033[0m"

def get_failures(summary):
    """create list of samples that failed the griphin summary"""
    df = pd.read_csv(summary, header=0, sep="\t", dtype="str")
    df_fails = df[df["Minimum_QC_Check"].str.contains("FAIL")]
    failed_id_list = df_fails["WGS_ID"].tolist()
    #write failed ids to text
    with open("failed_ids.txt", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(failed_id_list)
    return failed_id_list

def filter_dir_samplesheet(failed_id_list, directory_samplesheet):
    """remove samples that failed from directory samplesheet so they aren"t in the downstream analysis"""
    df = pd.read_csv(directory_samplesheet, header=0, sep=",", dtype="str")
    print(df)
    df = df[~df["sample"].isin(failed_id_list)] #remove failed samples
    if df.empty:
        raise ValueError("After removing failures there are no samples left. At least 3 passing isolates are needed for analysis.")
    df.to_csv("Directory_samplesheet_pass.csv", index=False)


def get_taxa_st_status(summary, failed_id_list, mlst_column, combine_complex):
    """
    Determines which Taxa/ST combinations should be excluded from the by-ST SNVPhyl run, and whether the by-ST section is worth running at all.

    Two independent exclusion reasons are tracked separately, since they need different treatment
    depending on whether the pipeline is also running an all-samples comparison (--no_all):
        1) redundant_taxa: The taxa as a whole has only one unique value in `mlst_column` -- running it by-ST would be redundant, but ONLY if an all-samples run also exists to cover it.
        2) insufficient_samples: The combination has fewer than 2 passing samples -- there aren't enough isolates to make a meaningful comparison, regardless of --no_all.

    `mlst_column` must match whichever MLST scheme get_sequence_types.py groups samples by (Primary_MLST by default, or Secondary_MLST when --use_secondary_mlst is passed), 
    so that redundancy is evaluated against the same grouping the by-ST run will actually use.

    Set combine_complex to the same value used in get_sequence_types.py.
    When True, species within the same complex are treated as one taxon using collapse_species_complex().
    This keeps both scripts consistent when determining whether a taxon has one or multiple STs.

    Rows with a non-conventional ST call (containing "-"), a "Novel_allele" call, or a "Novel_profile" call are dropped before grouping, matching get_sequence_types.py's clean_df/novel_df filtering,
    so both scripts agree on which rows are even eligible to form a Taxa/ST group.

    Failed samples are dropped before counting, since they won't be part of any downstream analysis anyway. 

    Writes:
        - redundant_taxa.txt: one '<Taxa>_<ST>' entry per combo excluded for being the taxon's only ST. Only meaningful to apply when an all-samples run also exists (--no_all not passed).
        - insufficient_samples.txt: one '<Taxa>_<ST>' entry per combo excluded for having <2 passing samples. Always applies, regardless of --no_all.
        - by_st_eligible.txt: 'true' if at least one combination is both non-redundant AND has enough samples, 'false' otherwise (used to gate the whole by-ST section when --no_all is not passed).

    Returns a tuple of (redundant_taxa, insufficient_samples, eligible_combo_count, exclusion_samples), where exclusion_samples maps each excluded combo to (reason, [WGS_IDs]). 
    run_information.txt can report which actual samples were affected and why.
    """
    df = pd.read_csv(summary, header=0, sep="\t", dtype="str")
    if mlst_column not in df.columns:
        raise ValueError(f"Column '{mlst_column}' not found in summary file. Available MLST-related columns should include 'Primary_MLST' and/or 'Secondary_MLST'.")
    # Only count samples that will actually make it into downstream analysis
    df = df[~df["WGS_ID"].isin(failed_id_list)]
    # Drop rows missing taxa or MLST info so they don't pollute the grouping
    df_valid = df.dropna(subset=["Final_Taxa_ID", mlst_column]).copy()
    # Collapse species complex members into a single taxa label first, matching get_sequence_types.py's ordering, before filtering.
    # The two operations act on independent columns so order has no practical effect on the result, but matching it removes any doubt.
    if combine_complex:
        df_valid["Final_Taxa_ID"] = df_valid["Final_Taxa_ID"].apply(collapse_species_complex)
    # Drop rows with a non-conventional ST (contains "-"), a Novel_allele call, or a Novel_profile call,
    # matching get_sequence_types.py's clean_df/novel_df filtering, so both scripts agree on which rows
    # are eligible to form a Taxa/ST group.
    df_valid = df_valid[~df_valid[mlst_column].str.contains("-", na=False)]
    df_valid = df_valid[~df_valid[mlst_column].str.contains("Novel_allele", na=False)]
    df_valid = df_valid[~df_valid[mlst_column].str.contains("Novel_profile", na=False)]

    exclusion_samples = {}  # combo -> (reason, [WGS_IDs])

    if df_valid.empty:
        # Mirrors get_sequence_types.py's ValueError when nothing survives the "-"/Novel_allele/Novel_profile filtering
        print(CRED + "After removing non-conventional, Novel_allele, and Novel_profile STs there are no samples left to evaluate for by-ST redundancy. The by-ST section will be skipped entirely." + CEND)
        with open("redundant_taxa.txt", "w", newline="") as f:
            pass
        with open("insufficient_samples.txt", "w", newline="") as f:
            pass
        with open("by_st_eligible.txt", "w") as f:
            f.write("false\n")
        return [], [], 0, exclusion_samples

    redundant_taxa = []
    insufficient_samples = []
    eligible_combo_count = 0

    # Group by taxa first to check how many unique ST values that taxa has overall
    for taxa, taxa_group in df_valid.groupby("Final_Taxa_ID"):
        taxa_clean = str(taxa).strip().replace(" ", "_")
        unique_sts = taxa_group[mlst_column].unique()
        taxa_is_single_st = len(unique_sts) == 1

        # Then check each Taxa/ST combo's passing sample count
        for st, st_group in taxa_group.groupby(mlst_column):
            st_clean = st.strip()
            combo = f"{taxa_clean}_{st_clean}"
            sample_ids = st_group["WGS_ID"].tolist()
            has_enough_samples = len(st_group) >= 2
            if not has_enough_samples:
                insufficient_samples.append(combo)
                exclusion_samples[combo] = ("insufficient_samples", sample_ids)
            elif taxa_is_single_st:
                redundant_taxa.append(combo)
                exclusion_samples[combo] = ("redundant_taxa", sample_ids)
            else:
                eligible_combo_count += 1

    # Always write both lists, even if empty, so Nextflow's output block and downstream
    # channel gating always have a file to read
    with open("redundant_taxa.txt", "w", newline="") as f:
        for entry in redundant_taxa:
            f.write(f"{entry}\n")
    with open("insufficient_samples.txt", "w", newline="") as f:
        for entry in insufficient_samples:
            f.write(f"{entry}\n")

    # Eligibility flag reflects the --no_all==false case: is there anything worth running by-ST
    # that ISN'T already covered by an all-samples run?
    with open("by_st_eligible.txt", "w") as f:
        f.write("true\n" if eligible_combo_count > 0 else "false\n")

    return redundant_taxa, insufficient_samples, eligible_combo_count, exclusion_samples


def write_run_information(failed_id_list, by_st, exclusion_samples):
    """
    Writes a succinct, human-readable summary of which samples were removed from which runs and why.

    Covers two independent removal events:
        1) Samples that failed QC -- removed from every downstream analysis (all-samples and by-ST alike).
        2) (--by_st only) Samples whose Taxa/ST combination was excluded from the by-ST run specifically, grouped by reason (redundant single-ST taxa, or fewer than 2 passing samples for that combo).

    This does not attempt to state whether an all-samples run exists to still cover a given sample,
    since --no_all is a Nextflow-level parameter not passed to this script.
    """
    lines = []
    lines.append("=" * 70)
    lines.append("PhyloPhoenix Sample Removal Summary")
    lines.append("=" * 70)
    lines.append("")

    # Section 1: QC failures -- removed from all analyses entirely
    lines.append(f"Samples removed for failing QC (excluded from all analyses): {len(failed_id_list)}")
    if failed_id_list:
        for sample in failed_id_list:
            lines.append(f"  - {sample}")
    else:
        lines.append("  (none)")
    lines.append("")

    # Section 2: by-ST-specific exclusions, only relevant if --by_st was passed
    if by_st:
        redundant_combos = {c: s for c, (reason, s) in exclusion_samples.items() if reason == "redundant_taxa"}
        insufficient_combos = {c: s for c, (reason, s) in exclusion_samples.items() if reason == "insufficient_samples"}

        lines.append("-" * 70)
        lines.append("Samples excluded from the by-ST run (--by_st)")
        lines.append("-" * 70)
        lines.append("")

        lines.append(f"Reason: taxon has only one ST -- redundant with an all-samples run, if one is run ({len(redundant_combos)} combo(s)):")
        if redundant_combos:
            for combo, samples in redundant_combos.items():
                lines.append(f"  {combo}:")
                for sample in samples:
                    lines.append(f"    - {sample}")
        else:
            lines.append("  (none)")
        lines.append("")

        lines.append(f"Reason: fewer than 2 passing samples for this taxa/ST combination ({len(insufficient_combos)} combo(s)):")
        if insufficient_combos:
            for combo, samples in insufficient_combos.items():
                lines.append(f"  {combo}:")
                for sample in samples:
                    lines.append(f"    - {sample}")
        else:
            lines.append("  (none)")
        lines.append("")
    else:
        lines.append("-" * 70)
        lines.append("--by_st was not passed: no by-ST-specific exclusions to report.")
        lines.append("-" * 70)
        lines.append("")

    with open("run_information.txt", "w", newline="") as f:
        f.write("\n".join(lines) + "\n")


def main():
    args = parseArgs()
    # If a directory is given then create a samplesheet from it if not use the samplesheet passed
    failed_id_list = get_failures(args.summary)
    filter_dir_samplesheet(failed_id_list,args.directory_samplesheet)
    exclusion_samples = {}
    if args.by_st:
        mlst_column = "Secondary_MLST" if args.use_secondary_mlst else "Primary_MLST"
        redundant_taxa, insufficient_samples, eligible_combo_count, exclusion_samples = get_taxa_st_status(args.summary, failed_id_list, mlst_column, args.combine_complex)
        if redundant_taxa:
            print(CRED + f"The following taxa/ST combinations have only one ST for their taxa (based on {mlst_column}, combine_complex={args.combine_complex}) and will be excluded from the by-ST run IF an all-samples run also exists to cover them: {', '.join(redundant_taxa)}" + CEND)
        if insufficient_samples:
            print(CRED + f"The following taxa/ST combinations have fewer than 2 passing samples (based on {mlst_column}, combine_complex={args.combine_complex}) and will always be excluded from the by-ST run, regardless of --no_all: {', '.join(insufficient_samples)}" + CEND)
        if eligible_combo_count == 0:
            print(CRED + f"No taxa/ST combination (based on {mlst_column}, combine_complex={args.combine_complex}) has more than one ST for its taxa AND at least 2 passing samples -- if --no_all is not set, the by-ST section will be skipped entirely." + CEND)
    else:
        # Ensure files always exist so Nextflow's output block doesn't fail
        open("redundant_taxa.txt", "w").close()
        open("insufficient_samples.txt", "w").close()
        open("by_st_eligible.txt", "w").close()

    write_run_information(failed_id_list, args.by_st, exclusion_samples)

if __name__ == "__main__":
    main()