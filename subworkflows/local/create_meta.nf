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
        samplesheets     // headers: id,seq_type,assembly_1,assembly_2
        snv_samplesheets // headers: id,directory
        metadata
        split_by_st  // true or false

    main: 
        ch_versions = Channel.empty() // Used to collect the software versions

        // flatten so some samplesheet is to create [ meta.id, meta.st] then group by st type collect them all and pass again to create list for each ST type
        st_scaffolds = samplesheets.flatten() //flatten so one samplesheet goes through at a time
            .splitCsv( header:true, sep:',' ) // split incoming samplesheet one row at a time
            .map{ create_assembly_channel(it) } // creates create [ [ meta.id, meta.st], assembly_1, assembly_2 ] for reach sample

        // header will be --> id,seq_type,assembly_1,assembly_2
        st_samplesheets = samplesheets.flatten()
            .map{ add_st_to_samplesheet(it, "st") }

        // header will be --> id,directory
        st_snv_samplesheets = snv_samplesheets.flatten()
            .map{ add_st_to_samplesheet(it, "st_snv") }

        if (params.metadata!=null) {
            if (split_by_st==true) {
                split_metadata_ch = st_snv_samplesheets.combine(metadata)
                //split metadata file by st
                SPLIT_METADATA_BY_ST (
                    split_metadata_ch
                )
                ch_versions = ch_versions.mix(SPLIT_METADATA_BY_ST.out.versions)
                split_metadata = SPLIT_METADATA_BY_ST.out.split_metadata
            } else {
                // when All_Isolates are running through don't split then just pass it and move along
                split_metadata = metadata.map{ it -> add_meta(it) }
            }
        } else {
            split_metadata = []
        }

    emit:
        st_scaffolds        = st_scaffolds   // channel: [ val(meta), [ scaffolds_1, scaffolds_2 ] ]
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
        meta.seq_type = seq_type
        def new_samplesheet = [ meta, file(samplesheet) ]
        return new_samplesheet
    }
    if (samplesheet_type == "st_snv") {
        def pre_seq_type = samplesheet.toString().replaceAll("SNVPhyl_", "") // remove _samplesheet.csv from path
        pre_seq_type = pre_seq_type.toString().replaceAll("_samplesheet_pre.csv", "") // remove _samplesheet.csv from path
        def seq_type = pre_seq_type.toString().split('/')[-1] // get the last string after the last backslash
        def meta = [:]
        meta.seq_type = seq_type
        def new_samplesheet = [ meta, file(samplesheet) ]
        return new_samplesheet
    }
}

def add_meta(metadata) {
    // create meta map
    def meta = [:]
    //meta.id = row.sample
    meta.seq_type = "All_Isolates"
    return [meta, metadata]
}

// Function to get list of [ meta, [ scaffolds_1, scaffolds_2 ] ]
def create_assembly_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id = row.sample
    meta.seq_type = row.seq_type

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


/*def create_st_tuples(input) {
    // the output of this function is to get a tuple like this:
    // [[[id:sample1, st:ST1], $PATH/sample1.filtered.scaffolds.fa.gz], [id:sample2, st:ST1], $PATH/sample2.filtered.scaffolds.fa.gz], [[id:sample3, st:ST2], $PATH/sample3.filtered.scaffolds.fa.gz], [id:sample4, st:ST2], $PATH/sample4.filtered.scaffolds.fa.gz]]
    //println(input)
    def starting_st = "ST" // initializing st
    count = 0
    sample_num = 1
    for (item in input) { // loop through each st type
        if ( count == 0 || count % 2 == 0) { // even number or zero it will be meta information, odd number will be the sample info 
            // get the current st
            new_st = item.st
            if (starting_st == new_st) { // if the new st is the same as the last st
                // add it to the tuple that was created before
                new_st_tuple.add(item)
                new_st_tuple.add(input.get(sample_num)[0])
            } else {
                // if the incoming st is a new one
                if (count == 0 ) { // check if this is the first time through and create an empty list if so
                    final_tuple = []
                } else { // if this is not the first time through add the completed tuple to the final list
                    // add the last tuple the final tuple then
                    final_tuple.add(new_st_tuple)
                }
                // set new st type
                starting_st = new_st
                // create a new tuble
                new_st_tuple = [new_st]
                // add current sample to this table
                new_st_tuple.add(item)
                new_st_tuple.add(input.get(sample_num)[0])
            }
            sample_num = sample_num + 2
            count = count + 1
        } else { // if count is an even number then only just add to variables
            count = count + 1
        }
    }
    return final_tuple
}*/