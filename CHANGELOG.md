# cdcgov/phylophoenix: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0dev](https://github.com/CDCgov/phylophoenix/releases/tag/v1.0dev) (06/11/2025)

🎉First official release.🎉

## [v1.1.0](https://github.com/CDCgov/phylophoenix/releases/tag/v1.1.0) (XX/XX/2026)

[Full Changelog](https://github.com/CDCgov/phylophoenix/compare/v1.0dev...v1.1.0)

**Implemented Enhancements:** 
- Window size default set to 500bp to align with SNVPhyl paper. Closes [#7](https://github.com/CDCgov/phylophoenix/issues/7).  
- SNVPhyl now splits analysis by taxa creating taxa specific sheets in final output.  
- Big-5 genes (NDM, IMP, KPC, VIM, OXA-48 like, ) added to metadata files when its provided.  
- GRiPHin module and python script updated to be inline with [PHoeNIx pipeline](https://github.com/CDCgov/phoenix).  
- Similar to PHoeNIx moved container calling to sha256 instead of tag.  
- Refactored pipeline to remove generate_line modules.  
- Added window size and hqSNV range information to griphin report.  
- Now separates by taxa automatically for analysis.  

**Fixed Bugs:** 
- Fixed --blind_list samples being excluded from by_st.  
- Fixed unmerging and color-coding SNVPhyl sub-header.  
- Blinded --blind_list samples in SNVPhyl section of GRiPHin report.  
- Fixed failures being deleted in original directory samplesheet.  

**Container Updates:**  
- BCFTools updated from 1.15 to [1.22](https://github.com/samtools/bcftools/releases/tag/1.22).  
- FreeBayes updated from  1.3.6 to [1.3.10](https://github.com/freebayes/freebayes/releases/tag/v1.3.10).  
- Phyml was updated from 3.3.20220408 to [3.3.20250515](https://github.com/stephaneguindon/phyml/releases/tag/v3.3.20250515).  
- Updated modules using phoenix base container from base_v2.1.0 to [base_v2.2.0](https://github.com/CDCgov/phoenix/blob/main/Dockerfiles/Dockerfile_base).  
- snvphyl-tools

**Config updates,phyml container and testmode :**
- Added testdata for user testing and validation.
- Updated test and nextflow config to enable singularity support 
- Added custom PhyML docker container to resolve the phyml:command not found issue and "Illegal instruction" error due to environment incompatibilities at runtime.(quay.io/aginni/phyml:3.3.20250515_4)
- Updated the action download artiact version - addressing the security vulnerabilities
