#!/usr/bin/env python3

#disable cache usage in the Python so __pycache__ isn't formed. If you don't do this using 'nextflow run cdcgov/phoenix...' a second time will causes and error
import sys
sys.dont_write_bytecode = True
import pandas as pd
import argparse
import os
import re
import logging
from datetime import datetime
import re
from re import search
import calendar
import math
from GRiPHin import find_big_5
# Import the COUNTRY_CODE_MAP from the country_code_map module
from country_code_map import COUNTRY_CODE_MAP
from country_code_map import COUNTRY_NAME_TO_CODE_MAP
from country_code_map import COUNTRY_DICT

# Function to get the script version
def get_version():
    return "1.0.0"

def parseArgs(args=None):
    parser = argparse.ArgumentParser(description="Add latitude and longitude to a dataset.")
    parser.add_argument("-i", "--input", required=True, help="Input TSV file") # ST345_metadata.tsv
    parser.add_argument("-o", "--output", required=True, help="Output TSV file") # ST345_preclean_metadata.tsv
    parser.add_argument("-l", "--log", default="offline_geocoding_errors.log",required=False, help="Error log file")
    parser.add_argument("-g", "--griphin_tsv", default="GRiPHin_Summary.tsv", required=True, help="Griphin file.")
    parser.add_argument('-b', '--bldb', default=None, required=False, dest='bldb', help='.')
    parser.add_argument('--version', action='version', version=get_version())# Add an argument to display the version
    return parser.parse_args()

#set colors for warnings so they are seen
CRED = '\033[91m'+'\nWarning: '
CYELLOW = '\033[93m'
CEND = '\033[0m'

# Constants: Paths to pre-processed datasets
US_DATA_FILE = "us_geolocation.txt"
EU_DATA_FILE = "eu_geolocation.txt"
AMERICAS_DATA_FILE = "americas_geolocation.txt"
AFRICA_DATA_FILE = "africa_geolocation.txt"
SA_DATA_FILE = "southeast_asia_geolocation.txt"
INTERNATIONAL_DATA_FILE = "other_international_geolocation.txt"

# Country and location mappings
US_COUNTRY_KEYWORDS = {"united states", "united states of america", "usa", "us", "US", "United States", "USA", "United States of America"} # US-related keywords for country matching
EU_COUNTRY_CODES = {"AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "ES", "FI", "FR", "GR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL", "PT", "RO", "SE", "SI", "SK"}
AMERICAS_COUNTRY_CODES = {"CA", "AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR", "UY", "VE"}
SEA_COUNTRY_CODES = {'BN', 'KH', 'ID', 'LA', 'MY', 'MM', 'PH', 'SG', 'TH', 'VN'}
AFRICA_COUNTRY_CODES = {'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD', 'KM', 'CD', 'CG', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'EH', 'ZM', 'ZW'}

# State name conversion for US states
US_STATE_ABBREVIATIONS = {
    'al': 'alabama', 'ak': 'alaska', 'az': 'arizona', 'ar': 'arkansas', 
    'ca': 'california', 'co': 'colorado', 'ct': 'connecticut', 'de': 'delaware',
    'fl': 'florida', 'ga': 'georgia', 'hi': 'hawaii', 'id': 'Idaho', 'il': 'illinois', 
    'in': 'indiana', 'ia': 'iowa', 'ks': 'kansas', 'ky': 'kentucky', 'la': 'louisiana', 
    'me': 'maine', 'md': 'maryland', 'ma': 'massachusetts', 'mi': 'michigan', 
    'mn': 'minnesota', 'ms': 'mississippi', 'mo': 'missouri', 'mt': 'montana', 
    'ne': 'nebraska', 'nv': 'nevada', 'nh': 'new hampshire', 'nj': 'new jersey', 
    'nm': 'new mexico', 'ny': 'new york', 'nc': 'north carolina', 'nd': 'north dakota', 
    'oh': 'ohio', 'ok': 'oklahoma', 'or': 'oregon', 'pa': 'pennsylvania', 
    'ri': 'rhode island', 'sc': 'south carolina', 'sd': 'south dakota', 'tn': 'tennessee', 
    'tx': 'texas', 'ut': 'utah', 'vt': 'vermont', 'va': 'virginia', 'wa': 'washington', 
    'wv': 'west virginia', 'wi': 'wisconsin', 'wy': 'wyoming'
}
STATE_CODES = {v: k for k, v in US_STATE_ABBREVIATIONS.items()}  # Reverse mapping

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger()

#def load_data(us_only):
#    """Load the appropriate GeoNames data based on whether the input is US-only."""
#    data_file = US_DATA_FILE if us_only else INTERNATIONAL_DATA_FILE
#    logger.info(f"Loading data from {data_file}...")
#    return pd.read_csv(data_file, sep='\t', low_memory=False)

def load_data(locations_needed):
    """Load the appropriate GeoNames data based on the country/location needed."""
    data = []
    # Check if data for specific regions is needed and load accordingly
    if "US" in locations_needed:
        logger.info("Loading US data...")
        data.append(pd.read_csv(US_DATA_FILE, sep='\t', low_memory=False))
    if "EU" in locations_needed:
        logger.info("Loading EU data...")
        data.append(pd.read_csv(EU_DATA_FILE, sep='\t', low_memory=False))
    if "AMERICAS" in locations_needed:
        logger.info("Loading Americas data...")
        data.append(pd.read_csv(AMERICAS_DATA_FILE, sep='\t', low_memory=False))
    if "INTERNATIONAL" in locations_needed:
        logger.info("Loading International data...")
        data.append(pd.read_csv(INTERNATIONAL_DATA_FILE, sep='\t', low_memory=False))
    if "AFRICA" in locations_needed:
        logger.info("Loading Africa data...")
        data.append(pd.read_csv(AFRICA_DATA_FILE, sep='\t', low_memory=False))
    if "SA" in locations_needed:
        logger.info("Loading SouthEast Asia data...")
        data.append(pd.read_csv(SA_DATA_FILE, sep='\t', low_memory=False))
    # Concatenate all dataframes
    if data:
        return pd.concat(data, ignore_index=True)
    else:
        return pd.DataFrame()  # Return an empty DataFrame if no data needed

def get_full_country_name(key):
    """Given a country name or code, returns the full country name."""
    for country, details in countries.items():
        # Check if key matches either country name or code
        if country.lower() == key.lower() or details["Code"].lower() == key.lower():
            return details["Full Country Name"]
    return f"Country {key} not found"

def safe_strip(value):
    """Safely strip whitespace from strings, handling NaN values."""
    if pd.isna(value) or value is None or str(value).strip() == '':
        return ""
    return value.strip().lower()

def contains_us_locations(input_data, data):
    """Check if the input data contains any US-related locations."""
    # Keywords to identify US as a country
    US_COUNTRY_KEYWORDS = {"united states", "usa", "us", "america"}
    # Helper function: Build state lookup from the provided data
    state_lookup = build_state_lookup(data)  
    # Safely retrieve the 'country' column or default to an empty Series
    countries_in_data = input_data.get('country', pd.Series()).fillna('').apply(safe_strip)
    # Safely retrieve the 'state' column or default to an empty Series
    states_in_data = input_data.get('state', pd.Series()).fillna('').apply(safe_strip)
    # Check if any valid US-related country is present in the 'country' column
    if any(country.lower() in US_COUNTRY_KEYWORDS for country in countries_in_data):
        return True, data  # Return True with the data
    # Check if any valid US state is present in the 'state' column
    elif any(state in state_lookup for state in states_in_data):
        return True, data  # Return True with the data
    # If neither country nor state matches, return False with the data
    else:
        return False, data

def build_state_lookup(data):
    """Create lookup dictionaries for state names and abbreviations."""
    us_states = data[data['country_code'].str.lower() == 'us']
    code_to_coords = {}  # Map state codes to latitude/longitude

    for _, row in us_states.iterrows():
        state_name = safe_strip(row['name'])
        state_code = safe_strip(row['admin1_code'])

        if state_name and state_code:
            code_to_coords[state_code] = (row['latitude'], row['longitude'])
    return code_to_coords

def is_empty(value):
    """Check if value is None, NaN, empty string, or only whitespace."""
    return pd.isna(value) or str(value).strip() == '' or value == "nan"

def find_lat_lon(row, data, state_lookup):
    """Find the most specific latitude/longitude for the given row."""
    country = safe_strip(row.get('country', ''))
    country_code = safe_strip(row.get('country_code', ''))
    state = safe_strip(row.get('state', ''))
    city = safe_strip(row.get('city', ''))
    county = safe_strip(row.get('county', ''))

    # If only a country is provided, return the center coordinates of the country
    if country and is_empty(state) and is_empty(city) and is_empty(county):
        if country.lower() in {"united states", "usa", "us", "united states of america"}:
            country = "United States"
            print(f'Searching for {country}.')
            result = data[data['name'].str.lower() == country.lower()]
        else:
            print(f'Searching for {country}.')
            result = data[(data['name'].str.contains(country, case=False, na=False)) & (data['country_code'].str.lower() == country_code.lower()) & (data['feature_code'] == "PCLI")]
        if not result.empty:
            return result.iloc[0][['latitude', 'longitude']].values

    # If only a state is provided, return the center coordinates of the state
    if state and is_empty(city) and is_empty(county):
        # Convert state name to its fill name
        if state.lower() in STATE_CODES:
            state = STATE_CODES[state.lower()]
        print(f'Searching for {state}.')
        return state_lookup.get(state, (None, None))

    # If a county is provided, return the center of that county in the given state
    if state and county and not city:
        # Convert state name to its abbreviation
        if state.lower() in STATE_CODES:
            state = STATE_CODES[state.lower()]
        county = county + " county"
        print(f'Searching for {county} in {state}.')
        #county_cleaned = re.sub(r'\scounty$', '', county, flags=re.IGNORECASE)
        result = data[(data['name'].str.lower() == county.lower()) &
                      (data['admin1_code'].str.lower() == state.lower())]
        if not result.empty:
            return result.iloc[0][['latitude', 'longitude']].values

    # If a city and state are provided, return the city center coordinates
    if state and city:
        # Convert state name to its abbreviation
        if state.lower() in STATE_CODES:
            state = STATE_CODES[state.lower()]
        print(f'Searching for {city} in {state}.')
        city_full_name = "City of " + city  # Handle cities like "City of Atlanta"
        result = data[(data['name'].str.lower().isin([city.lower(), city_full_name.lower()])) &
                      (data['admin1_code'].str.lower() == state.lower())]
        if not result.empty:
            return result.iloc[0][['latitude', 'longitude']].values

    # If no specific match, return (None, None)
    return None, None

def clean_month_column(data):
    """Convert month names or abbreviations to their corresponding month numbers."""
    # Create mappings for month names and abbreviations
    month_name_to_num = {name.lower(): num for num, name in enumerate(calendar.month_name) if name}
    month_abbr_to_num = {abbr.lower(): num for num, abbr in enumerate(calendar.month_abbr) if abbr}

    def convert_month(value):
        """Helper function to convert month name/abbr to its corresponding number."""
        # If it's already an integer and a valid month number, return it as-is
        if isinstance(value, (int, float)) and 1 <= value <= 12 and value.is_integer():
            return int(value)

        # Handle string cases (month names or abbreviations)
        value_lower = str(value).strip().lower()
        if value_lower in month_name_to_num:
            return int(month_name_to_num[value_lower])
        elif value_lower in month_abbr_to_num:
            return int(month_abbr_to_num[value_lower])

        # Return None if the value is invalid, with a warning message
        print(f"Warning: Invalid month value '{value}'")
        return None

    # Apply the conversion to the "month" column if it exists
    if 'month' in data.columns:
        data['month'] = data['month'].apply(convert_month).astype('Int64')

    return data

def make_allele_column(df_sub, gene_prefix):
    """
    Creates a Series of allele hits for a given gene (e.g. NDM, VIM, IMP).
    Returns None if no matches exist anywhere in any row for that gene.
    """
    # columns that contain the gene prefix in the name
    gene_cols = [c for c in df_sub.columns if gene_prefix in c and c != 'WGS_ID']
    print(f"Found columns for {gene_prefix}: {gene_cols}")

    def get_alleles(row):
        present_cols = []
        for col in gene_cols:
            val = row[col]
            if pd.notna(val) and str(val).strip() != '':
                present_cols.append(col.split('_')[0])  # Extract allele name from column name
        return ','.join(present_cols) if present_cols else ''

    return df_sub.apply(get_alleles, axis=1)

def merge_summary_with_metadata(metadata, summary_file, output_file, BLDB):
    """Merge GRiPHin_Summary.tsv with metadata file on 'WGS_ID' and save the result."""
    # Load metadata and summary files
    summary = pd.read_csv(summary_file, sep='\t', dtype='str')

    # Determine the appropriate organism column to use -- allows backward compatibility 
    if 'Final_Taxa_ID' in summary.columns:
        organism_column = 'Final_Taxa_ID'
    else:
        organism_column = 'FastANI_Organism'

    # add big 5 genes
    # 1. Identify the column range between AR_Database and HV_Database (inclusive)
    cols = list(summary.columns)
    # Subset: WGS_ID + columns between AR_Database and HV_Database
    subset_cols = ['WGS_ID'] + cols[cols.index('AR_Database'):cols.index('HV_Database')+1]
    sub = summary[subset_cols]
    gene_allele_cols = []
    # 2. Create allele columns for NDM, VIM, IMP on the original dataframe
    # 2a get list of big 5 genes
    columns_to_highlight = []
    all_genes = sub.columns.tolist()
    all_genes = [x for x in all_genes if x not in {'WGS_ID', 'AR_Database', 'No_AR_Genes_Found', 'HV_Database'}]
    big5_keep, big5_oxa_keep= find_big_5(BLDB)
    # loop through column names and check if they contain a gene we want highlighted. Then add to highlight list if they do. 
    for gene in all_genes: # loop through each gene in the dataframe of genes found in all isolates
        gene_name = gene.split('_(')[0] # remove drug name for matching genes
        drug = gene.split('_(')[1] # keep drug name to add back later
        if "-like" in gene_name:
            gene_name = gene_name.split('_bla')[0] # remove blaOXA-1-like name for matching genes -- just extra stuff that doesn't allow complete match
        # make sure we have a complete match for oxa 48/23/24/58/143 genes and oxa 48/23/24/58/143-like genes
        if "OXA" in gene_name: #check for complete blaOXA match
            [ columns_to_highlight.append(gene_name + "_(" + drug) for big5_oxa in big5_oxa_keep if gene_name == big5_oxa ]
        else: # for "blaIMP", "blaVIM", "blaNDM", and "blaKPC", this will take any thing with a matching substring to these
            [ columns_to_highlight.append(gene_name + "_(" + drug) for big5 in big5_keep if search(big5, gene_name) ]
    print(CYELLOW + "\nhighlighting colums:", columns_to_highlight, CEND)

    for gene in ['NDM', 'VIM', 'IMP', 'KPC']:
        print(f"Searching for '{gene}'.")
        col_name = f'{gene}_Alleles'
        result = make_allele_column(sub, gene)
        if result.eq("").all():
            pass  # No matches found for this gene; do not add column
        else:
            summary[col_name] = result
            gene_allele_cols.append(col_name)  # remember this column exists
    # Select relevant columns from the GRiPHin summary file
    basecols = ['WGS_ID', organism_column, 'Primary_MLST', 'Secondary_MLST']
    # Only include gene_alleles columns that are actually present in summary
    existing_gene_cols = [c for c in gene_allele_cols if c in summary.columns]
    summary_subset = summary[ basecols + existing_gene_cols]
    # Merge on 'WGS_ID'
    merged_data = pd.merge(summary_subset, metadata, left_on='WGS_ID', right_on='sample', how='inner')
    #we don't need to ID columns so drop one
    merged_data = merged_data.drop(columns=['sample'])

    # Save the merged result to a new TSV file
    merged_data.to_csv(output_file, sep='\t', index=False)

def get_country_codes(metadata):
    """
    Replace two-letter country codes in the 'country' column of the metadata DataFrame
    with full country names, except for the US which should remain as 'US'.
    """
    # Function to replace codes with full names
    def get_full_country_name(code):
        if code in US_COUNTRY_KEYWORDS:
            return 'US'  # Keep US as is
        else:
            if len(str(code)) == 2:
                return code
                #return COUNTRY_CODE_MAP.get(code, code)  # Replace or keep original if not found
            else:
                return COUNTRY_NAME_TO_CODE_MAP.get(code, code)  # Replace or keep original if not found
    # Apply the function to the 'country' column
    metadata['country'] = metadata['country'].apply(get_full_country_name)
    return metadata

def reverse_country_codes(metadata):
    """
    Replace two-letter country codes in the 'country' column of the metadata DataFrame
    with full country names, except for the US which should remain as 'US'.
    """
    # Function to replace codes with full names
    def get_full_country_name(code):
        if code in US_COUNTRY_KEYWORDS:
            return 'US'  # Keep US as is
        else:
            if len(str(code)) == 2:
                return COUNTRY_CODE_MAP.get(code, code)  # Replace or keep original if not found
            else:
                return code
    def get_country_code(code):
        if code in US_COUNTRY_KEYWORDS:
            return 'US'  # Keep US as is
        elif code in US_COUNTRY_KEYWORDS: #fix for UK
            return 'US'  # Keep US as is
        else:
            return COUNTRY_NAME_TO_CODE_MAP.get(code, code)  # Replace or keep original if not found
    metadata['country_code'] = metadata['country'].apply(get_country_code)
    def get_full_country_name(key):
        """Given a country name or code, returns the full country name."""
        # Check if the key is None, NaN, or blank
        if not key or (isinstance(key, float) and math.isnan(key)):
            return key
        for country, details in COUNTRY_DICT.items():
            # Check if key matches either country name or code
            if country.lower() == key.lower() or details["Code"].lower() == key.lower():
                return details["Full Country Name"]
        return f"Country {key} not found"  # Correct way to reference the key
        # Apply the function to the 'country' column
    metadata['country'] = metadata['country'].apply(get_full_country_name)
    return metadata

def standardize_location_columns(df):
    """
    Standardize column names in the DataFrame for location-based columns.
    Specifically, rename any column containing 'country', 'county', 'state', or 'city'
    (regardless of case) to the exact term. Throws an error if there are duplicate matches.
    """
    # Define the target keywords for renaming
    keywords = ['country', 'county', 'state', 'city']
    new_column_names = {}  # Dictionary to store original-to-new column mappings

    # Iterate over each keyword and check for matches in column names
    for keyword in keywords:
        matching_columns = [col for col in df.columns if keyword in col.lower()]
        
        # Check for conflicts
        if len(matching_columns) > 1:
            raise ValueError(f"Multiple columns found matching '{keyword}': {matching_columns}. "
                            "Please resolve these duplicates before standardizing.")
        
        if len(matching_columns) == 1:
            # Check if target keyword is already a column in the DataFrame
            if keyword in df.columns and matching_columns[0].lower() != keyword:
                raise ValueError(f"Column '{keyword}' already exists in the DataFrame, which conflicts with "
                                f"the matched column '{matching_columns[0]}'. Please resolve this conflict.")
            
            # Map the matched column name to the standardized keyword
            new_column_names[matching_columns[0]] = keyword

    # Rename the columns based on the new mappings
    df = df.rename(columns=new_column_names)
    return df

def main(input_file, output_file, log_file, griphin_tsv, BLDB):
    """Process the data by adding latitude, longitude, cleaning month, and converting dates."""
    # Load input data
    # Automatically detect delimiter (comma, tab, etc.)
    input_data = pd.read_csv(input_file, sep=None, engine="python", dtype='str')
    input_data.columns = input_data.columns.str.lower().str.replace(" ", "_").str.replace("-", "_") # Normalize column names to lowercase
    print(input_data.columns)
    # Identify columns to drop by index
    input_data = input_data.drop(columns=['country.1', 'state.1','amr_genotypes'], errors='ignore')
    input_data = input_data.rename(columns={"sample.1": 'SRR'})
    # Check if the first column's name is 'sample'
    if 'sample' in input_data.columns:
        # Move 'sample' column to first position
        cols = input_data.columns.tolist()
        cols.insert(0, cols.pop(cols.index('sample')))
        input_data = input_data[cols]
    else:
        # Rename first column to 'sample'
        first_column_name = input_data.columns[0]
        print(f"Warning: Renaming first column '{first_column_name}' to 'sample'.")
        input_data = input_data.rename(columns={first_column_name: 'sample'})

    # Check if the DataFrame contains any rows (besides headers)
    if input_data.empty or all(input_data.isna().all()):
        raise ValueError(f"The metadata file '{input_file}' is empty or contains only headers. Something went wrong. Check upstream in SPLIT_METADATA step for cause of error.")

    input_data = standardize_location_columns(input_data)

    # Skip geolocation lookup if any required columns are missing
    required_columns = {'country', 'county', 'state', 'city'}
    # Check if there's at least one required column in the data
    has_required_columns = bool(required_columns & set(input_data.columns))

    if has_required_columns == True:
        # Trigger the error or handle the case when 'county' or 'city' are present without 'state'
        if ('county' in input_data.columns or 'city' in input_data.columns) and 'state' not in input_data.columns:
            raise ValueError("Geolocation lookup error: 'county' and 'city' are provided without 'state'.")
    else:
        # If no required columns are present, log a warning to skip geolocation lookup
        logger.warning("Skipping geolocation lookup due to missing columns. You need at least 1: country, county, state and city. Additionally, you need 'state' if you provide 'county' and/or 'city'.")

    #skip_geolocation = not required_columns.issubset(input_data.columns)
    #if skip_geolocation:
    #    logger.warning(f"Skipping geolocation lookup due to missing columns: {', '.join(required_columns - set(input_data.columns))}")

    if has_required_columns == True:
        # Quick clean of location columns
        for column in required_columns & set(input_data.columns):
            # Replace underscores with spaces in the column values
            input_data[column] = input_data[column].astype(str).str.replace('_', ' ')

        # Is there is no country column and US states are present in the state column then add US column
        # Convert the abbreviations dictionary to a set of all valid states (both full names and abbreviations)
        valid_states = set(US_STATE_ABBREVIATIONS.values()) | set(US_STATE_ABBREVIATIONS.keys())

        # Check for column existence (case insensitive)
        columns = [col.lower() for col in input_data.columns]

        if 'state' in columns and 'country' not in columns:
            # Create 'country' column and set all values to 'United States' for valid US states
            input_data['country'] = input_data['state'].apply(lambda x: 'United States' if x.lower() in valid_states else None)

        # Country code conversion if 'country' column exists
        loc_data = get_country_codes(input_data) if 'country' in input_data.columns else input_data

        # convert two letter country codes
        loc_data = get_country_codes(input_data)
        # Check for countries that do not match any of the provided codes
        # Combine the country code sets using union()
        country_code_set = (US_COUNTRY_KEYWORDS.union(EU_COUNTRY_CODES).union(AFRICA_COUNTRY_CODES).union(SEA_COUNTRY_CODES).union(AMERICAS_COUNTRY_CODES))
        unknown_countries = loc_data[~loc_data['country'].isin(country_code_set)]

        # Load geolocation data based on the input metadata
        locations_needed = []
        if loc_data['country'].str.contains('|'.join(US_COUNTRY_KEYWORDS), case=False).any():
            locations_needed.append("US")
        if loc_data['country'].isin(EU_COUNTRY_CODES).any():
            locations_needed.append("EU")
        if loc_data['country'].isin(AFRICA_COUNTRY_CODES).any():
            locations_needed.append("AFRICA")
        if loc_data['country'].isin(SEA_COUNTRY_CODES).any():
            locations_needed.append("SA")
        if loc_data['country'].isin(AMERICAS_COUNTRY_CODES).any():
            locations_needed.append("AMERICAS")
        if not unknown_countries.empty:
            locations_needed.append("INTERNATIONAL")

        # convert country information for accurate look up
        input_data = reverse_country_codes(input_data)

        # Load the US data once and check if input contains US locations
        needed_data = load_data(locations_needed)
        us_only, data = contains_us_locations(input_data, needed_data)  # Get both flag and data

        logger.info("Done loading data, making state look up...")

        # Build a state lookup dictionary for US data if needed
        state_lookup = build_state_lookup(data) if us_only else {}

    # Clean the "month" column if present
    input_data = clean_month_column(input_data)

    errors = []
    for idx, row in input_data.iterrows():
        if has_required_columns == True:
            try:
                # Find latitude and longitude
                lat, lon = find_lat_lon(row, data, state_lookup)
                if pd.isna(lat) or pd.isna(lon):
                    raise ValueError(f"Could not find lat/lon for {row.to_dict()}")

                # Add lat/lon to the DataFrame
                input_data.loc[idx, 'latitude'] = lat
                input_data.loc[idx, 'longitude'] = lon

            except ValueError as e:
                error_msg = f"Row {idx + 1}: {str(e)}"
                errors.append(error_msg)
                logger.warning(error_msg)

    # Identify columns with "date" in their name
    date_columns = [col for col in input_data.columns if 'date' in col.lower()]

    # Loop through each row, converting the format for each "date"-related column
    for date_col in date_columns:
        if date_col in input_data.columns:
            parsed = pd.to_datetime(input_data[date_col], errors="coerce")
            bad = parsed.isna() & input_data[date_col].astype(str).str.strip().ne("")
            if bad.any():
                print(f"{date_col}: {bad.sum()} invalid dates")
            input_data[date_col] = parsed.dt.strftime("%Y-%m-%d").fillna("")

    merge_summary_with_metadata(input_data, griphin_tsv, output_file, BLDB)

    # Write errors to log file
    with open(log_file, 'w') as f:
        for error in errors:
            f.write(error + '\n')

if __name__ == "__main__":
    args = parseArgs()
    main(args.input, args.output, args.log, args.griphin_tsv, args.bldb)
