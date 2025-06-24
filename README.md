# 🔥🌿🐦🔥PhyloPHoeNIx: Pipeline for relatedness determination using PHoeNIx output.

[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/phylophoenix/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-core/phylophoenix)

[![Get help on Slack](http://img.shields.io/badge/slack-StaPH--B%20%23phoenix--dev-4A154B?labelColor=000000&logo=slack)](https://staph-b-dev.slack.com/channels/phoenix-dev)

#### Metrics

<!---[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fcdcgov%2Fphoenix&count_bg=%233DC8A9&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=Page+Hits&edge_flat=false)](https://hits.seeyoufarm.com)

 ![GitHub Clones](https://img.shields.io/github/downloads/cdcgov/phoenix/total.svg?style=social&logo=github&label=Clones-)  --->

[![Custom Badge](https://img.shields.io/badge/GitHub-%F0%9F%94%A5%F0%9F%8C%BF%F0%9F%90%A6%F0%9F%94%A5%20GitHub%20Clones%3A%20176-blue?logo=GitHub&style=for-the-badge&logoColor=black&label=%20&labelColor=white&color=blue&style=flat-square)](https://github.com/)  


## Introduction

🔥🌿🐦🔥 PhyloPHoeNIx is meant to be run in tandem with [🔥🐦🔥 PHoeNIx](https://github.com/CDCgov/phoenix/wiki/) to aid in outbreak investigations by estimating relatedness between samples. Both pipelines were built and are maintained by bioinformatians in the **CDC's [Division of Healthcare Quality Promotion (DHQP)](https://www.cdc.gov/ncezid/divisions-offices/about-dhqp.html?CDC_AAref_Val=https://www.cdc.gov/ncezid/dhqp/index.html)** to standardize surveillance of [antibiotic resistance threats](https://www.cdc.gov/antimicrobial-resistance/media/pdfs/antimicrobial-resistance-threats-update-2022-508.pdf), identification of novel resistance threats and support public health laboratories in their genomic analysis of healthcare-associated infection organisms. PhyloPHoeNIx is a comprehensive pipeline that performs:  

- Automation of DHQP's iterative outbreak analysis (runs analysis on all samples and when --by_st is passed also separates isolates by ST and runs each group through the analysis)  
- SNV (single-nucleotide variant) matrix creation  
- Phylogenetic tree building  
- Reports the % core genome used in the SNV determination  

**cdcgov/phylophoenix** is a bioinformatics best-practice analysis pipeline for relatedness determination using PHoeNIx output.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. 

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.1`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/) or [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)) for full pipeline reproducibility.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run cdcgov/phylophoenix -profile test,singularity --outdir <OUTDIR>
   ```
   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker` and `singularity` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enable you to store and re-use the images from a central location for future pipeline runs.

4. Start running your own analysis!

## Pipeline overview

| PhyloPHoeNIx  | SNVPhyl |
| ------- | ------- |
| ![Image 1](https://github.com/user-attachments/assets/7aea0957-28c3-4b4a-9555-5a7294200ba5) | ![Image 2](https://github.com/user-attachments/assets/1c27c8dd-66b0-42cb-9e5f-f45f30305a81) |

## Running PhyloPHoeNIx

### Inputs

You can either input samples using a typical nextflow samples sheet. This samplesheet should have the columns `sample,directory`. Here the directory would be to a sample's directory within a larger PHoeNIx output directory. For example, your samplesheet should look like this:

```
sample,directory
2023BB-00546,/PATH/PHX_output_dir/2023BB-00546
2023BB-00847,/PATH/PHX_output_dir/2023BB-00847
```

This method is useful for combining samples from different PHoeNIx directories and the full command would look like this:

   ```bash
   nextflow run cdcgov/phylophoenix -profile singularity --outdir <OUTDIR> --input Directory_samplesheet.csv
   ```

Alternatively, if you want to analyze all samples in one PHoeNIx output directory you can pass the path to `--input_dir` and a samplesheet as described above will be created from all samples in this directory. Using this method the full command would look like this:  

   ```bash
   nextflow run cdcgov/phylophoenix -profile singularity --outdir <OUTDIR> --indir <PATH TO PHOENIX DIR>
   ```

By default PhyloPHoeNIx creates a SNV matrix and phylogenetic tree from all samples that pass QC in the directory. If you want to also group samples by MLST and create additional SNV matrices and phylogenetic trees for each MLST pass the `--by_st` argument.  

   ```bash
   nextflow run cdcgov/phylophoenix -profile singularity --outdir <OUTDIR> --input Directory_samplesheet.csv --by_st
   ```

If you want to skip running all samples together and just want to run in `--by_st` mode add the `--no_all` parameter.  

   ```bash
   nextflow run cdcgov/phylophoenix -profile singularity --outdir <OUTDIR> --input Directory_samplesheet.csv --by_st --no_all
   ```

**A minimum of 3 samples of the same MLST are required to create a SNV matrix and phylogenetic tree.**

### Outputs

Here is an example output file tree that is reduced for space (3 samples are the min for creating a phylogenetic tree).

📦phylophoenix_output  
 ┣ 📂\<ST>  
 ┃ ┣ 📂\<sample_id>  
 ┃ ┃ ┣ 📜\<sample_id>.bam   
 ┃ ┃ ┣ 📜\<sample_id>\_sorted.bam      
 ┃ ┃ ┣ 📜\<sample_id>\_filtered\_density.txt            
 ┃ ┃ ┣ 📜\<sample_id>\_freebayes\_filtered.vcf.gz     
 ┃ ┃ ┣ 📜\<sample_id>\_freebayes.vcf            
 ┃ ┃ ┗ 📜\<sample_id>\_mpileup.vcf.gz  
 ┃ ┣ 📜\<ST>\_centroid\_info.txt   
 ┃ ┣ 📜\<ST>\_cleaned\_metadata.tsv   --> upload to Microreact  
 ┃ ┣ 📜\<ST>\_SNVPhyl.newick  --> upload to Microreact/iTol or another visualisation program  
 ┃ ┣ 📜\<ST>\_snvAlignment.phy  
 ┃ ┣ 📜\<ST>\_snvMatrix.tsv  --> upload to Microreact  
 ┃ ┣ 📜\<ST>\_vcf2core.tsv  
 ┃ ┣ 📜filtered_density_all.txt    
 ┃ ┣ 📜filterStats.txt   
 ┃ ┣ 📜mappingQuality.txt   
 ┃ ┣ 📜new_invalid_positions.bed  
 ┃ ┗ 📜TreeStats_SNVPhyl.txt  
 ┣ 📂ST_SampleSheets  
 ┃ ┗ \<ST>\_samplesheet.csv  
 ┣ 📂pipeline_info  
 ┃ ┣ 📜execution_report_<date>.html  
 ┃ ┣ 📜execution_timeline_<date>.html     
 ┃ ┣ 📜execution_trace_<date>.txt   
 ┃ ┣ 📜pipeline_dag_<date>.html   
 ┃ ┣ 📜samplesheet.valid.csv  
 ┃ ┗ 📜software_versions.yml    
 ┣ 📜Directory_samplesheet.csv   
 ┣ 📜SNVPhyl_GRiPHin_Summary.xlsx  
 ┗ 📜GRiPHin_Summary.xlsx  

## Credits

The core of PhyloPHoeNIx is a pipleline originally developed by @apetkau (Aaron Petkau), called SNVPhyl. There are standalone [Nextflow](https://github.com/DHQP/SNVPhyl_Nextflow), [Galaxy](https://github.com/phac-nml/snvphyl-galaxy/), and [WDL] versions of SNVPhyl if you prefer to use those. For documentation on SNVPhyl see the following links.

- [SNVPhyl Paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5628696/)
- [SNVPhyl Documenation](https://phac-nml.github.io/irida-documentation/administrator/galaxy/pipelines/phylogenomics/)

We thank the following people for their extensive assistance and test in the development of this pipeline:

* Nick Vlachos [@nvlachos](https://github.com/nvlachos)
* Thao Masters [@masters-thao](https://github.com/masters-thao)
* Alyssa Kent [@Alyssa-Kent](https://github.com/Alyssa-Kent)

Add beta testers here....

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#phylophoenix` channel](https://nfcore.slack.com/channels/phylophoenix) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  nf-core/phylophoenix for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).


# CDCgov GitHub Organization Open Source Project

**General disclaimer** This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise. 

## Access Request, Repo Creation Request

* [CDC GitHub Open Project Request Form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUNk43NzMwODJTRzA4NFpCUk1RRU83RTFNVi4u) _[Requires a CDC Office365 login, if you do not have a CDC Office365 please ask a friend who does to submit the request on your behalf. If you're looking for access to the CDCEnt private organization, please use the [GitHub Enterprise Cloud Access Request form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUQjVJVDlKS1c0SlhQSUxLNVBaOEZCNUczVS4u).]_

## Related documents

* [Open Practices](open_practices.md)
* [Rules of Behavior](rules_of_behavior.md)
* [Thanks and Acknowledgements](thanks.md)
* [Disclaimer](DISCLAIMER.md)
* [Contribution Notice](CONTRIBUTING.md)
* [Code of Conduct](code-of-conduct.md)

## Overview

Describe the purpose of your project. Add additional sections as necessary to help collaborators and potential collaborators understand and use your project.
  
## Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License Standard Notice
The repository utilizes code licensed under the terms of the Apache Software
License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md)
and [Code of Conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice
This repository is not a source of government records, but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

## Additional Standard Notices
Please refer to [CDC's Template Repository](https://github.com/CDCgov/template)
for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/master/CONTRIBUTING.md),
[public domain notices and disclaimers](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md),
and [code of conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).

