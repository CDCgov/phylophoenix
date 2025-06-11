//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channels(it) }
        .set { reads }

    //get list of STs in the data set, we will use this later to sort files by ST
    st_list = reads.collect().map{ get_sts(it) }

    emit:
    reads             = reads // channel: [ val(meta), [ reads ] ]
    valid_samplesheet = SAMPLESHEET_CHECK.out.csv
    st_list           = st_list
    versions          = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channels(LinkedHashMap row) {
    def meta = [:]
    meta.seq_type     = row.seq_type
    meta.id           = row.sample
    //meta.single_end   = row.single_end.toBoolean()

    def array = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (meta.single_end) {
        array = [ meta, [ file(row.fastq_1) ] ]
    } else {
        if (!file(row.fastq_2).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
        }
        array = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }
    return array
}

def get_sts(input_ch){
    // create a list of the ST in the data set 
    count = 0 // inti count
    def st_list = []
    for (isolate in input_ch) { // loop through each st type
        if ( count == 0 || count % 2 == 0) { // even number or zero it will be meta information, odd number will be the sample info
            sequence_type = isolate.seq_type // get st
            st_list.add(sequence_type.toString()) // add st to list
        }
        count = count + 1
    }
    //get the unique st's
    def unique_st = st_list.unique()
    return unique_st
}