Register<bit<16>, bit<32>>(32w65536) heap_s<stage-id>;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s<stage-id>) heap_write_s<stage-id> = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s<stage-id>) heap_read_s<stage-id> = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};