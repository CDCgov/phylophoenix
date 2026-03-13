import pandas as pd
import sys
from pathlib import Path

def xlsx_to_tsv(file):
    """
    Reads an Excel file and writes it out as a TSV.
    Expects file without extension (e.g., 'data' for data.xlsx).
    """

    # Read Excel file
    data_xlsx = pd.read_excel( file + '.xlsx', sheet_name='Sheet1', index_col=None, header=[1] )

    # Drop last 11 rows
    data_xlsx = data_xlsx.iloc[:-11]

    # Write dataframe to TSV
    data_xlsx.to_csv( file + '.tsv', sep='\t', encoding='utf-8', index=False, lineterminator='\n' )

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python xlsx_to_tsv.py <filename_without_extension>")
        sys.exit(1)

    filename = sys.argv[1]
    xlsx_to_tsv(filename)