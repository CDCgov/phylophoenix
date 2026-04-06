#!/usr/bin/env python3

#disable cache usage in the Python so __pycache__ isn't formed. If you don't do this using 'nextflow run cdcgov/phoenix...' a second time will causes and error
import sys
sys.dont_write_bytecode = True
import pandas as pd
import argparse
import glob
import os
import re
import xlsxwriter as ws
from xlsxwriter.utility import xl_rowcol_to_cell
import openpyxl
from openpyxl.styles import PatternFill, Font
from copy import copy
import numpy as np

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Add latitude and longitude to a dataset.")
    parser.add_argument("-g", "--griphin", required=True, help="Input GRiPHin_Summary.xlsx file")
    parser.add_argument('-b', '--blind_list', default=None, required=False, dest='blind_list', help='CSV file with a list of sample_name,new_name. This option will output the new_name rather than the sample name to "blind" reports.')
    parser.add_argument('-w', '--window_size', default=None, required=False, dest='window_size', help='Window size for SNVPhyl analysis.')
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

def blind_map(control_file):
    """If you passed a file to -c this will swap out sample names to 'blind' the WGS_IDs in the final excel file."""
    rename_mapping = {}
    with open(control_file, 'r') as controls:
        header = next(controls) # skip the first line of the samplesheet
        for line in controls:
            old_sample_name = line.split(",")[0]
            new_sample_name = line.split(",")[1].rstrip("\n")
            if new_sample_name != '' and new_sample_name != old_sample_name:
                rename_mapping[old_sample_name] = new_sample_name
    return rename_mapping

def copy_sheet_dimensions(src_ws, dst_ws):
    # Column widths
    for col, dim in src_ws.column_dimensions.items():
        dst_ws.column_dimensions[col].width = dim.width

def copy_header_merges(src_ws, dst_ws, max_row=1):
    """
    Copy merged cell ranges from src_ws to dst_ws
    but only if the merged range starts within the first `max_row` rows.
    """
    for merged_range in list(src_ws.merged_cells.ranges):
        if merged_range.min_row <= max_row:
            dst_ws.merge_cells(str(merged_range))

def sanitize_sheet_name(taxa_name):
    """Convert taxa name to valid Excel sheet name."""
    # Replace space with underscore for "genus species" format
    sheet_name = taxa_name.replace(" ", "_")
    
    # Remove any special characters that Excel doesn't allow in sheet names
    # Excel doesn't allow: / \ ? * [ ] :
    sheet_name = re.sub(r'[/\\?*\[\]:]', '', sheet_name)
    
    # If longer than 31 characters, truncate genus to first letter
    if len(sheet_name) > 31:
        parts = sheet_name.split("_")
        if len(parts) >= 2:
            sheet_name = parts[0][0] + "_" + "_".join(parts[1:])
        # If still too long, truncate to 31 characters
        if len(sheet_name) > 31:
            sheet_name = sheet_name[:31]
    
    return sheet_name

def copy_cell_style(source_cell, target_cell):
    target_cell.font = copy(source_cell.font)
    target_cell.border = copy(source_cell.border)
    target_cell.fill = copy(source_cell.fill)
    target_cell.number_format = source_cell.number_format
    target_cell.protection = copy(source_cell.protection)
    target_cell.alignment = copy(source_cell.alignment)

def create_taxa_sheets(workbook):
    """Create separate sheets for each unique taxa from Final_Taxa_ID column."""
    original_sheet = workbook.active
    # Find the Final_Taxa_ID column
    taxa_col_idx = None
    for col_idx, cell in enumerate(original_sheet[2], start=1):  # Check row 2 for column names
        if cell.value == "Final_Taxa_ID":
            taxa_col_idx = col_idx
            break
    if taxa_col_idx is None:
        raise ValueError("Could not find 'Final_Taxa_ID' column in the Excel file")
    # Get unique taxa (starting from row 3, after 2 header rows)
    taxa_set = set()
    taxa_rows = {}  # Dictionary to store rows for each taxa
    for row_idx in range(3, original_sheet.max_row - 11):
        taxa_value = original_sheet.cell(row=row_idx, column=taxa_col_idx).value
        # Check for blank/NA taxa
        if taxa_value is None or str(taxa_value).strip() == '' or str(taxa_value).upper() == 'NA':
            raise ValueError(f"Row {row_idx} has blank/NA value in Final_Taxa_ID column. This should not happen.")
        taxa_set.add(taxa_value)
        if taxa_value not in taxa_rows:
            taxa_rows[taxa_value] = []
        taxa_rows[taxa_value].append(row_idx)
    # Create a sheet for each unique taxa
    taxa_sheet_mapping = {}  # Map taxa to sheet names
    for taxa in sorted(taxa_set):
        sheet_name = sanitize_sheet_name(taxa)
        # Create new sheet
        new_sheet = workbook.create_sheet(title=sheet_name)
        # Copy sets dimensions BEFORE writing cells
        copy_sheet_dimensions(original_sheet, new_sheet)
        # Copy the 2 header rows
        for row_idx in range(1, 3):
            for col_idx in range(1, original_sheet.max_column + 1):
                source_cell = original_sheet.cell(row=row_idx, column=col_idx)
                target_cell = new_sheet.cell(row=row_idx, column=col_idx)
                # Copy value
                target_cell.value = source_cell.value
                # Copy formatting
                if source_cell.has_style:
                    copy_cell_style(source_cell, target_cell)
        # Copy sets header merges
        copy_header_merges(original_sheet, new_sheet)
        # Copy data rows for this taxa
        new_row_idx = 3
        for original_row_idx in taxa_rows[taxa]:
            for col_idx in range(1, original_sheet.max_column + 1):
                source_cell = original_sheet.cell(row=original_row_idx, column=col_idx)
                target_cell = new_sheet.cell(row=new_row_idx, column=col_idx)
                # Copy value
                target_cell.value = source_cell.value
                # Copy formatting
                if source_cell.has_style:
                    copy_cell_style(source_cell, target_cell)
            new_row_idx += 1
        # Store mapping of taxa to sheet name
        taxa_sheet_mapping[taxa.replace(" ", "_")] = sheet_name
    return taxa_sheet_mapping

def extract_taxa_from_filename(filename):
    """Extract taxa name from SNVMatrix filename."""
    basename = os.path.basename(filename)
    # Remove _snvMatrix.tsv
    taxa = basename.replace('_snvMatrix.tsv', '')
    # Remove All_ prefix if present
    if taxa.startswith('All_'):
        taxa = taxa[4:]  # Remove 'All_'
    # Remove _Isolates suffix if present
    taxa = taxa.replace('_Isolates', '')
    # Extract first two parts (genus_species) in case there are additional parts like ST307
    parts = taxa.split('_')
    if len(parts) >= 2:
        taxa = f"{parts[0]}_{parts[1]}"
    return taxa

def append_tsv_to_excel(workbook, snvmatrices, result_dict, blind_list, taxa_sheet_mapping, window_size,snv_range):
    """Append SNVPhyl matrices to their corresponding taxa sheets."""

    # Group SNVMatrix files by taxa
    taxa_files = {}
    for snvmatrix in snvmatrices:
        taxa = extract_taxa_from_filename(snvmatrix)
        if taxa not in taxa_files:
            taxa_files[taxa] = []
        taxa_files[taxa].append(snvmatrix)

    # If blind_list exists, create mapping
    rename_mapping = None
    if blind_list is not None:
        rename_mapping = blind_map(blind_list)

    # Process each taxa's SNVMatrix files
    for taxa, files in taxa_files.items():
        # Find the corresponding sheet
        sheet_name = taxa_sheet_mapping.get(taxa)
        if sheet_name is None:
            print(f"WARNING: No matching taxa sheet found for SNVMatrix files with taxa '{taxa}'. Files: {files}")
            continue
        sheet = workbook[sheet_name]
        # Determine starting row
        start_row = sheet.max_row + 2
        # Define formatting
        bold_font = Font(bold=True)
        count = 0
        for snvmatrix in files:
            # Load the TSV file data
            snvmatrix_df = pd.read_csv(snvmatrix, sep='\t', dtype='str')
            if rename_mapping is not None:
                snvmatrix_df['WGS_ID'] = snvmatrix_df['WGS_ID'].replace(rename_mapping)
                snvmatrix_df = snvmatrix_df.rename(columns=rename_mapping)
            # Add section header on first file
            if count == 0:
                snvmatrix_cell = sheet.cell(row=start_row, column=1, value="SNVPhyl Analysis: SNV Matrices")
                snvmatrix_cell.fill = PatternFill(start_color="D8BFD8", end_color="D8BFD8", fill_type="solid")
                snvmatrix_cell.font = Font(bold=True)
                sheet.cell(row=start_row, column=2).fill = PatternFill(start_color="D8BFD8", end_color="D8BFD8", fill_type="solid")
                sheet.cell(row=start_row, column=3).fill = PatternFill(start_color="D8BFD8", end_color="D8BFD8", fill_type="solid")
                count = 1

            # Derive seq_type from filename
            seq_type = os.path.basename(snvmatrix).replace('_snvMatrix.tsv', '')
            # Write seq_type label
            sheet.cell(row=start_row + 1, column=1, value=seq_type).font = bold_font
            # Extract and write reference
            ref_without_asterisk = [col for col in snvmatrix_df.columns if col.endswith('*')][0][:-1]
            if rename_mapping is not None and ref_without_asterisk in rename_mapping:
                ref_without_asterisk = rename_mapping[ref_without_asterisk]
            sheet.cell(row=start_row + 2, column=1, value="Reference:")
            sheet.cell(row=start_row + 2, column=2, value=ref_without_asterisk)
            # Write Window Size
            sheet.cell(row=start_row + 3, column=1, value="Window size:")
            sheet.cell(row=start_row + 3, column=2, value=str(window_size))
            # Write core genome percentage
            sheet.cell(row=start_row + 4, column=1, value="SNVPhyl core estimate:")
            sheet.cell(row=start_row + 4, column=2, value=str(result_dict.get(seq_type)) + "%")
            # Write core genome percentage
            sheet.cell(row=start_row + 5, column=1, value="hqSNV Range:")
            sheet.cell(row=start_row + 5, column=2, value=str(snv_range.get(seq_type)))
            # Write header
            for col_idx, column_name in enumerate(snvmatrix_df.columns, start=1):
                sheet.cell(row=start_row + 7, column=col_idx, value=column_name).font = bold_font
            # Write data
            for i, row in snvmatrix_df.iterrows():
                for j, value in enumerate(row):
                    sheet.cell(row=start_row + i + 8, column=j + 1, value=value)
            # Update start_row for next file
            start_row += len(snvmatrix_df) + 8

def get_sorted_files(pattern):
    # Retrieve all matching files
    files = glob.glob(pattern)
    # Separate files containing the All_*_Isolates pattern and those that don't
    All_Isolates_files = [f for f in files if re.search(r'All.*Isolates', f)]
    print(All_Isolates_files)
    other_files = [f for f in files if not re.search(r'All.*Isolates', f)]
    # Define function to extract numbers for sorting
    def extract_number(filename):
        match = re.search(r'\d+', filename)
        return int(match.group()) if match else float('inf')  # float('inf') puts files without numbers at the end
    # Sort remaining files by extracted number, then alphabetically for files without numbers
    other_files.sort(key=lambda f: (extract_number(f), f))
    # Concatenate lists with All_Isolates_files first
    return All_Isolates_files + other_files

def get_files():
    # You only need this for glob because glob will throw an index error if not.
    snvmatrices = get_sorted_files("*_snvMatrix.tsv")
    vcf2cores = get_sorted_files("*_vcf2core.tsv")
    #create empty dictionary to fill
    result_dict = {}
    # create snv_range mapping: seq_type -> "min - max"
    snv_range = {}
    # looping through vcf2core files
    for vcf2core in vcf2cores:
        # Derive seq_type from the filename by removing '_vcf2core.tsv'
        seq_type = os.path.basename(vcf2core).replace('_vcf2core.tsv', '')
        # Read the TSV file
        df_vcf2core = pd.read_csv(vcf2core, sep='\t',dtype='str')
        # Extract the last row's specified column value as a float - to get % core genome
        try:
            last_value = float(df_vcf2core["Percentage of all positions that are valid, included, and part of the core genome"].iloc[-1])
            result_dict[seq_type] = last_value
        except (KeyError, ValueError, IndexError) as e:
            print(f"Error processing file '{vcf2core}': {e}")
    # collect SNV min-max ranges
    for snvmatrix in snvmatrices:
        seq_type = os.path.basename(snvmatrix).replace('_snvMatrix.tsv', '')
        try:
            # Read first column as row names
            df = pd.read_csv(snvmatrix, sep='\t', index_col=0, dtype='str')
            # Convert everything to numeric where possible
            df = df.apply(pd.to_numeric, errors='coerce')
            # Make sure row names and column names are comparable strings
            df.index = df.index.astype(str).str.strip()
            df.columns = df.columns.astype(str).str.strip()
            # Keep only shared sample names so matrix is square
            shared_names = [name for name in df.index if name in df.columns]
            df = df.loc[shared_names, shared_names]
            if df.empty or df.shape[0] < 2:
                snv_range[seq_type] = "NA"
                continue
            arr = df.to_numpy(dtype=float)
            # Exclude diagonal and NaN
            non_diag_mask = ~np.eye(arr.shape[0], dtype=bool)
            values = arr[non_diag_mask]
            values = values[~np.isnan(values)]
            if values.size == 0:
                snv_range[seq_type] = "NA"
            else:
                min_val = values.min()
                max_val = values.max()
                # format nicely
                if float(min_val).is_integer():
                    min_val = int(min_val)
                if float(max_val).is_integer():
                    max_val = int(max_val)
                snv_range[seq_type] = f"{min_val} - {max_val}"
                print(f"SNV range for {seq_type}: {snv_range[seq_type]}")
        except Exception as e:
            print(f"Error reading snvMatrix '{snvmatrix}': {e}")
            snv_range[seq_type] = "NA"
    return snvmatrices, result_dict, snv_range

def main():
    args = parseArgs()
    old_griphin = args.griphin
    # Load workbook
    workbook = openpyxl.load_workbook(old_griphin)
    # Create taxa sheets
    taxa_sheet_mapping = create_taxa_sheets(workbook)
    # Get SNVMatrix files and core genome data
    snvmatrices, result_dict, snv_range = get_files()
    print(snvmatrices, result_dict)
    # Append SNVPhyl data to taxa sheets
    append_tsv_to_excel(workbook, snvmatrices, result_dict, args.blind_list, taxa_sheet_mapping, args.window_size, snv_range)
    # Save the final output file
    workbook.save("SNVPhyl_GRiPHin_Summary.xlsx")
    print("Excel file with taxa sheets and SNVPhyl data saved as 'SNVPhyl_GRiPHin_Summary.xlsx'.")

if __name__ == "__main__":
    main()