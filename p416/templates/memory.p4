Register<bit<32>, bit<32>>(32w65536) heap_s<stage-id>;

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_write_s<stage-id> = {
    void apply(inout bit<32> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_bulk_write_s<stage-id> = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_<stage-id>;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_read_s<stage-id> = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_count_s<stage-id> = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
        value = value + 1;
    }
};