#!/usr/bin/env python3
"""
species_complexes.py

Shared species-complex definitions and collapsing logic used across the
PhoeNix/PhyloPhoenix scripts, so taxa belonging to a recognized species
complex (e.g. Citrobacter freundii complex) are consistently grouped
together under one complex-level name wherever taxa grouping happens
(sample sheet generation, Excel sheet splitting, SNV matrix file naming).

Import into other scripts with:
    from species_complexes import collapse_species_complex
"""

# Species complexes: map each complex's display name to the set of member
# species (base binomial/trinomial only - strain suffixes are handled
# separately via the prefix-match logic in collapse_species_complex).
SPECIES_COMPLEXES = {
    "Citrobacter freundii complex": {
        "Citrobacter braakii",
        "Citrobacter cronae",
        "Citrobacter freundii",
        "Citrobacter gillenii",
        "Citrobacter murliniae",
        "Citrobacter portucalensis",
        "Citrobacter sedlakii",
        "Citrobacter werkmanii",
        "Citrobacter youngae",
    },
    "Acinetobacter baumannii complex": {
        "Acinetobacter baumannii",
        "Acinetobacter calcoaceticus",
        "Acinetobacter lactucae",
        "Acinetobacter nosocomialis",
        "Acinetobacter pittii",
        "Acinetobacter seifertii",
    },
    "Enterobacter cloacae complex": {
        "Enterobacter asburiae",
        "Enterobacter cancerogenus",
        "Enterobacter cf. cloacae",
        "Enterobacter chengduensis",
        "Enterobacter chuandaensis",
        "Enterobacter cloacae",
        "Enterobacter hormaechei",
        "Enterobacter hoffmannii",
        "Enterobacter kobei",
        "Enterobacter ludwigii",
        "Enterobacter pasteurii",
        "Enterobacter roggenkampii",
        "Enterobacter sichuanensis",
    },
    "Burkholderia cepacia complex": {
        "Burkholderia aenigmatica",
        "Burkholderia ambifaria",
        "Burkholderia anthina",
        "Burkholderia arboris",
        "Burkholderia catarinensis",
        "Burkholderia cenocepacia",
        "Burkholderia cepacia",
        "Burkholderia cf. cepacia",
        "Burkholderia contaminans",
        "Burkholderia diffusa",
        "Burkholderia dolosa",
        "Burkholderia lata",
        "Burkholderia latens",
        "Burkholderia metallica",
        "Burkholderia multivorans",
        "Burkholderia orbicola",
        "Burkholderia paludis",
        "Burkholderia pseudomultivorans",
        "Burkholderia puraquae",
        "Burkholderia pyrrocinia",
        "Burkholderia semiarida",
        "Burkholderia seminalis",
        "Burkholderia sola",
        "Burkholderia stabilis",
        "Burkholderia stagnalis",
        "Burkholderia territorii",
        "Burkholderia ubonensis",
        "Burkholderia vietnamiensis",
    },
}

# Raw taxa labels that already represent an unclassified/complex-level call
# in the source data, mapped to the desired output complex name. These won't
# match the plain species-name prefix check below, so they're handled as an
# explicit lookup instead.
UNCLASSIFIED_COMPLEX_LABELS = {
    "Citrobacter freundii complex sp.": "Citrobacter freundii complex",
    "Acinetobacter calcoaceticus/baumannii complex sp.": "Acinetobacter baumannii complex",
    "unclassified Acinetobacter calcoaceticus/baumannii complex": "Acinetobacter baumannii complex",
    "unclassified Enterobacter cloacae complex": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade K": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade L": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade N": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade O": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade P": "Enterobacter cloacae complex",
    "Enterobacter cloacae complex clade S": "Enterobacter cloacae complex",
    "Enterobacter genomosp. O": "Enterobacter cloacae complex",
    "Enterobacter genomosp. S": "Enterobacter cloacae complex",
    "unclassified Burkholderia cepacia complex": "Burkholderia cepacia complex",
}

def collapse_species_complex(taxa_name):
    """Collapse individual species belonging to a recognized species complex into the complex-level name, so they group together under one taxon.
    Expects space-separated genus/species names (not underscore-converted).
    Extend SPECIES_COMPLEXES / UNCLASSIFIED_COMPLEX_LABELS above to add more complexes or handle additional edge-case labels.
    """
    if taxa_name is None:
        return taxa_name
    taxa_str = str(taxa_name).strip()
    # Direct lookup for unclassified/complex-level labels already present
    # verbatim in the source data.
    if taxa_str in UNCLASSIFIED_COMPLEX_LABELS:
        return UNCLASSIFIED_COMPLEX_LABELS[taxa_str]
    for complex_name, member_species in SPECIES_COMPLEXES.items():
        # Already labeled as the complex - leave as-is.
        if taxa_str == complex_name:
            return complex_name
        # "<complex name> sp." / "<complex name> sp.XXXX" style entries
        if taxa_str.startswith(complex_name + " sp."):
            return complex_name
        # Match species name allowing for a trailing strain identifier,
        # e.g. "Citrobacter freundii 47N" -> "Citrobacter freundii"
        for species in member_species:
            if taxa_str == species or taxa_str.startswith(species + " "):
                return complex_name
    return taxa_str