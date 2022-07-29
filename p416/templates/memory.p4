Register<bit<32>, bit<32>>(32w65536) heap_s<stage-id>;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_write_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_increment_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_accumulate_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = obj + hdr.meta.mbr; 
        rv = obj;
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_increment_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};

/*
    Swap by mbr if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Write: hdr.meta.mbr2 = REGMAX.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_swap_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
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