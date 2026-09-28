//
// Getting ST types in order
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SPLIT_METADATA_BY_ST } from '../../modules/local/split_metadata_by_st'

workflow CREATE_META {
    take:
        samplesheets     // headers: id,seq_type,taxa,assembly_1,assembly_2
        snv_samplesheets // headers: id,directory,taxa
        metadata
        split_by_st  // true or false
        reads

    main: 
        ch_versions = Channel.empty() // Used to collect the software versions

        // flatten so some samplesheet is to create [ meta.id, meta.st] then group by st type collect them all and pass again to create list for each ST type
        st_scaffolds = samplesheets.flatten() //flatten so one samplesheet goes through at a time
            .splitCsv( header:true, sep:',' ) // split incoming samplesheet one row at a time
            .map{ create_assembly_channel(it) } // creates create [ [ meta.id, meta.st], assembly_1, assembly_2 ] for reach sample

        // header will be --> id,seq_type,assembly_1,assembly_2
        st_samplesheets = samplesheets.flatten()
            .map{ add_st_to_samplesheet(it, "st") }

        // Get meta.seq_type into reads channel. First, reshape st_scaffolds to extract just the meta information we need
        st_meta = st_samplesheets.map{ meta, samplesheet -> samplesheet}.flatten().splitCsv( header:true, sep:',' )
                                .map{ row -> [ row.sample, row.seq_type ] }
        // Join reads with st_meta based on meta.id
        st_reads = reads.map{ meta, fastqs -> [ meta.id, fastqs ] } // Add meta.id as key
            .combine(st_meta)
            .filter{ id, fastqs, sample, seq_type -> sample.contains(id) } // Check if sample string contains the id
            .map{ id, fastqs, sample, seq_type ->  [ [id:id, seq_type: seq_type], fastqs ]  }.unique() // Reconstruct with both meta fields

        st_snv_samplesheets = snv_samplesheets.flatten()
            .map{ add_st_to_samplesheet(it, "st_snv") }

        if (params.metadata!=null) {
            //if (split_by_st==true) {
                split_metadata_ch = st_snv_samplesheets.combine(metadata)
                //split metadata file by st
                SPLIT_METADATA_BY_ST (
                    split_metadata_ch
                )
                ch_versions = ch_versions.mix(SPLIT_METADATA_BY_ST.out.versions)
                split_metadata = SPLIT_METADATA_BY_ST.out.split_metadata
            /*} else {
                // when All_Isolates are running through don't split then just pass it and move along
                split_metadata = metadata.map{ it -> add_meta(it) }
            }*/
        } else {
            split_metadata = []
        }

    emit:
        st_scaffolds        = st_scaffolds   // channel: [ val(meta), [ scaffolds_1, scaffolds_2 ] ]
        st_reads            = st_reads          // channel: [ val(meta), [ reads_1, reads_2 ] ]
        st_samplesheets     = st_samplesheets // channel: [ seq_type, samplesheet ]
        st_snv_samplesheets = st_snv_samplesheets // channel: [ seq_type, samplesheet ]
        split_metadata      = split_metadata
        versions            = ch_versions // channel: [ versions.yml ]
}

/*def split_metadata_by_st(it) {
    def st_snv_samplesheets = it[1]
    def metadata = it[2]
    def seq_type = (st_snv_samplesheets =~ /_(.*?)_/)[0][1]
    if (seq_type == "All"){ seq_type = seq_type + "_STs" }
    def ids_to_keep = []
    // Open the file and read each line to get WGS_ID
    new File(st_snv_samplesheets.toString()).withReader { reader ->
        reader.readLine()  // Skip the first line
        reader.eachLine { line ->
            def columns = line.split(',')  // Split by comma
            if (columns) {
                ids_to_keep << columns[0].trim()  // Collect the first column
            }
        }
    }
    //split file to only keep rows with the WGS_ID we want.  
    // Read all lines from the input file
    def lines = new File(metadata.toString()).readLines()
    // Extract the header and initialize a list for filtered content
    def header = lines[0]
    def filteredLines = [header]  // Keep the header

    // Process the rest of the lines
    lines.tail().each { line ->
        def meta_columns = line.split(',')
        if (meta_columns && ids_to_keep.contains(meta_columns[0].trim())) {
            filteredLines << line  // Add matching line to filtered content
        }
    }

    // Rewrite the original file with filtered content
    new File(metadata.toString()).withWriter { writer -> 
        filteredLines.each { writer.writeLine(it) }
    }
    def meta = [:]
    meta.seq_type = seq_type
    return [meta, file(metadata)]
}*/

def add_st_to_samplesheet(samplesheet, samplesheet_type) {
    if (samplesheet_type == "st") {
        def pre_seq_type = samplesheet.toString().replaceAll("_samplesheet.csv", "") // remove _samplesheet.csv from path 
        def seq_type = pre_seq_type.toString().split('/')[-1] // get the last string after the last backslash
        def meta = [:]
        if (seq_type.startsWith("All_")) {
            meta.seq_type = seq_type // get only the seq_type from the full string
            //meta.taxa = pre_seq_type.toString().split('/')[-1].replaceAll("All_", "").replaceAll("_Isolates", "") // get taxa from seq_type
        } else {
            meta.seq_type = seq_type.split('_')[-1] // get only the seq_type from the full string
            //meta.taxa = pre_seq_type.toString().split('/')[-1].replaceFirst(/_[^_]*$/, '')  // get taxa from seq_type
        }
        def new_samplesheet = [ meta, file(samplesheet) ]
        return new_samplesheet
    }
    if (samplesheet_type == "st_snv") {
        def pre_seq_type = samplesheet.toString().replaceAll("SNVPhyl_", "") // remove _samplesheet.csv from path
        pre_seq_type = pre_seq_type.toString().replaceAll("_samplesheet_pre.csv", "") // remove _samplesheet.csv from path
        def seq_type = pre_seq_type.toString().split('/')[-1] // get the last string after the last backslash
        def meta = [:]
        //if (seq_type.startsWith("All_")) {
        meta.seq_type = seq_type // get only the seq_type from the full string
            //meta.taxa = pre_seq_type.toString().split('/')[-1].replaceAll("All_", "").replaceAll("_Isolates", "") // get taxa from seq_type
        //} else {
            //meta.seq_type = seq_type.split('_')[-1] // get only the seq_type from the full string
            //meta.taxa = pre_seq_type.toString().split('/')[-1].replaceFirst(/_[^_]*$/, '')  // get taxa from seq_type
        //}
        def new_samplesheet = [ meta, file(samplesheet) ]
        return new_samplesheet
    }
}

def add_meta(metadata) {
    // create meta map
    def meta = [:]
    //meta.id = row.sample
    //metadata = NY_isolate_metadata.txt
    meta.seq_type = "All_Isolates"
    //meta.taxa = 
    return [meta, metadata]
}

// Function to get list of [ meta, [ scaffolds_1, scaffolds_2 ] ]
def create_assembly_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id = row.sample
    meta.seq_type = row.seq_type
    //meta.taxa = row.taxa

    // add path(s) of the assembly file(s) to the meta map
    def assembly_meta = []
    if (!file(row.assembly_1).exists()) {
        exit 1, "ERROR: Please check st samplesheet -> Assembly scaffolds file does not exist!\n${row.assembly_1}"
    }
    if (!file(row.assembly_2).exists()) {
        exit 1, "ERROR: Please check st samplesheet -> Assembly scaffolds file does not exist!\n${row.assembly_2}"
    }
    assembly_meta = [ meta, file(row.assembly_1), file(row.assembly_2) ]
    return assembly_meta
}