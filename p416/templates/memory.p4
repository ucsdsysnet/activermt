Register<memory_object_t, bit<16>>(32w65536) heap_s<stage-id>;

RegisterAction<memory_object_t, bit<16>, bit<16>>(heap_s<stage-id>) heap_write_s<stage-id> = {
    void apply(inout memory_object_t obj, out bit<16> rv) {
        obj.key = hdr.meta.mbr2;
        obj.value = hdr.meta.mbr;
        rv = obj.value;
    }
};

RegisterAction<memory_object_t, bit<16>, bit<16>>(heap_s<stage-id>) heap_conditional_write_s<stage-id> = {
    void apply(inout memory_object_t obj, out bit<16> rv) {
        if(obj.value > hdr.meta.mbr) {
            obj.key = hdr.meta.mbr2;
            obj.value = hdr.meta.mbr;    
        }
        rv = obj.value;
    }
};

RegisterAction<memory_object_t, bit<16>, bit<16>>(heap_s<stage-id>) heap_count_s<stage-id> = {
    void apply(inout memory_object_t obj, out bit<16> rv) {
        if(obj.value > hdr.meta.mbr) {
            obj.key = hdr.meta.mbr2;
            obj.value = obj.value + 1;    
        }
        rv = obj.value;
    }
};

RegisterAction<memory_object_t, bit<16>, bit<16>>(heap_s<stage-id>) heap_read_s<stage-id> = {
    void apply(inout memory_object_t obj, out bit<16> rv) {
        rv = 0;
        if(obj.key == hdr.meta.mbr2) {
            rv = obj.value;
        }
    }
};

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_bulk_write_s<stage-id> = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_<data-id>;
    }
};*/