#!/bin/bash
# Downloads and extracts PHoeNIx test data from Zenodo

ZENODO_URL="https://zenodo.org/records/20560027/files/testoutput_phoenix.tar.gz"

echo "Downloading test data from Zenodo..."
wget -O testoutput_phoenix.tar.gz "$ZENODO_URL"

echo "Extracting test data..."
tar -xzvf testoutput_phoenix.tar.gz -C assets/

echo "Cleaning up..."
rm testoutput_phoenix.tar.gz

echo "Done! Test data is ready at assets/testoutput_phoenix/"