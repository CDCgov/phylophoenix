#!/bin/bash
# Downloads and extracts PHoeNIx test data from Zenodo

SCRIPT_DIR=$(dirname "$(realpath "$0")")
ZENODO_URL="https://zenodo.org/records/20548667/files/testoutput_phoenix.tar.gz"
# https://doi.org/10.5281/zenodo.20548667

ASSET_DIR="${SCRIPT_DIR}/assets/testoutput_phoenix"
SAMPLESHEET="${SCRIPT_DIR}/assets/testoutput_phoenix/Directory_samplesheet.csv"

echo "Downloading test data from Zenodo..."
wget -O testoutput_phoenix.tar.gz "$ZENODO_URL"

echo "Extracting test data..."
tar -xzvf testoutput_phoenix.tar.gz -C assets/

echo "Generating samplesheet..."
echo "sample,path" > "$SAMPLESHEET"

for dir in "$ASSET_DIR"/*/; do
    if [ -d "$dir" ]; then
        sample=$(basename "$dir")
        abs_path=$(realpath "$dir")
        echo "${sample},${abs_path}" >> "$SAMPLESHEET"
    fi
done

echo "Samplesheet written to: $(realpath "$SAMPLESHEET")"

echo "Cleaning up..."
rm testoutput_phoenix.tar.gz

echo "Done! Test data is ready at assets/testoutput_phoenix/"