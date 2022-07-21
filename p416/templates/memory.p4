Register<bit<16>, bit<16>>(32w65536) heap_s<stage-id>;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
RegisterAction<bit<16>, bit<16>, bit<16>>(heap_s<stage-id>) heap_conditional_write_s<stage-id> = {
    void apply(inout bit<16> obj, out bit<16> rv) {
        rv = obj;
        if(hdr.meta.mbr2 == 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
RegisterAction<bit<16>, bit<16>, bit<16>>(heap_s<stage-id>) heap_conditional_increment_s<stage-id> = {
    void apply(inout bit<16> obj, out bit<16> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};

/*
    Swap by mbr if current value is less than mbr.
*/
RegisterAction<bit<16>, bit<16>, bit<16>>(heap_s<stage-id>) heap_conditional_swap_s<stage-id> = {
    void apply(inout bit<16> obj, out bit<16> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr;
        } 
    }
};

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_bulk_write_s<stage-id> = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_<data-id>;
    }
};*/