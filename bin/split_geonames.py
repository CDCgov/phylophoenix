import pandas as pd
import argparse

# File paths
US_DATA_FILE = "us_geolocation.txt"
EU_DATA_FILE = "eu_geolocation.txt"
AMERICAS_DATA_FILE = "americas_geolocation.txt"
SEA_DATA_FILE = "southeast_asia_geolocation.txt"
AFRICA_DATA_FILE = "africa_geolocation.txt"
INTERNATIONAL_DATA_FILE = "other_international_geolocation.txt"

# Define country codes for each region (ISO 3166-1 alpha-2)
EU_COUNTRIES = {'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'}
AMERICAS_COUNTRIES = {'CA', 'AR', 'BO', 'BR', 'CL', 'CO', 'EC', 'GY', 'PY', 'PE', 'SR', 'UY', 'VE'}
SEA_COUNTRIES = {'BN', 'KH', 'ID', 'LA', 'MY', 'MM', 'PH', 'SG', 'TH', 'VN'}
AFRICA_COUNTRIES = {'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD', 'KM', 'CD', 'CG', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'EH', 'ZM', 'ZW'}

# Columns to drop for memory efficiency
COLUMNS_TO_DROP = ['population', 'elevation', 'dem', 'timezone']

# Define relevant feature classes to include all entries for "A", "P", and "S"
RELEVANT_FEATURE_CLASSES = {"A", "P", "S"}

def is_relevant_feature(row):
    """Check if the row represents a relevant feature based on feature_class."""
    return row['feature_class'] in RELEVANT_FEATURE_CLASSES

def split_geonames_data(geonames_file):
    """Split the allCountries.txt file into US, EU, South America, Southeast Asia, African, and other international datasets."""
    # Define column names
    columns = ['geonameid', 'name', 'asciiname', 'alternatenames', 'latitude', 'longitude', 'feature_class', 'feature_code',
               'country_code', 'cc2', 'admin1_code', 'admin2_code', 'admin3_code', 'admin4_code', 'population', 'elevation', 'dem', 'timezone', 'modification_date']

    # Read the GeoNames file in chunks to handle large size
    chunks = pd.read_csv(geonames_file, sep='\t', header=None, names=columns, chunksize=100000, low_memory=False)

    us_rows = []
    eu_rows = []
    americas_rows = []
    sea_rows = []
    africa_rows = []
    international_rows = []

    # Process each chunk
    for chunk in chunks:
        # Filter for relevant features (only "A", "P", "S" feature classes)
        chunk = chunk[chunk.apply(is_relevant_feature, axis=1)]

        # Drop unnecessary columns in each chunk immediately
        chunk.drop(columns=COLUMNS_TO_DROP, inplace=True, errors='ignore')

        # Split the data into US, EU, South America, Southeast Asia, Africa, and international rows
        us_chunk = chunk[chunk['country_code'] == 'US']
        eu_chunk = chunk[chunk['country_code'].isin(EU_COUNTRIES)]
        americas_chunk = chunk[chunk['country_code'].isin(AMERICAS_COUNTRIES)]
        sea_chunk = chunk[chunk['country_code'].isin(SEA_COUNTRIES)]
        africa_chunk = chunk[chunk['country_code'].isin(AFRICA_COUNTRIES)]
        international_chunk = chunk[~chunk['country_code'].isin(EU_COUNTRIES | AMERICAS_COUNTRIES | SEA_COUNTRIES | AFRICA_COUNTRIES) & (chunk['country_code'] != 'US')]

        # Append to respective lists
        us_rows.append(us_chunk)
        eu_rows.append(eu_chunk)
        americas_rows.append(americas_chunk)
        sea_rows.append(sea_chunk)
        africa_rows.append(africa_chunk)
        international_rows.append(international_chunk)

    # Concatenate and save to separate files
    pd.concat(us_rows).to_csv(US_DATA_FILE, sep='\t', index=False)
    pd.concat(eu_rows).to_csv(EU_DATA_FILE, sep='\t', index=False)
    pd.concat(americas_rows).to_csv(AMERICAS_DATA_FILE, sep='\t', index=False)
    if any(not df.empty for df in sea_rows):  # Check if sea_rows contains any non-empty DataFrames
        pd.concat(sea_rows).to_csv(SEA_DATA_FILE, sep='\t', index=False)
    else:
        # Create an empty DataFrame with the appropriate columns if sea_rows is empty
        empty_df = pd.DataFrame(columns=columns).drop(columns=COLUMNS_TO_DROP)
        empty_df.to_csv(SEA_DATA_FILE, sep='\t', index=False)

    pd.concat(africa_rows).to_csv(AFRICA_DATA_FILE, sep='\t', index=False)
    pd.concat(international_rows).to_csv(INTERNATIONAL_DATA_FILE, sep='\t', index=False)

    print(f"Data split complete. Saved US data to {US_DATA_FILE}, EU data to {EU_DATA_FILE}, South America/Canada data to {AMERICAS_DATA_FILE}, Southeast Asia data to {SEA_DATA_FILE}, African data to {AFRICA_DATA_FILE}, and international data to {INTERNATIONAL_DATA_FILE}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split the allCountries.txt file into US, EU, South America, Southeast Asia, African, and international datasets.")
    parser.add_argument("-i", "--input", required=True, help="Input TSV file")
    args = parser.parse_args()
    split_geonames_data(args.input)
