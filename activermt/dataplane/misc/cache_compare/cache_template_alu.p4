@stage(#)
Register<bit<32>, bit<32>>(32w<register_size>) heap_#_key;

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_#_key) heap_#_read_key = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
    }
};

action memory_#_read_key() {
    meta.key_# = heap_#_read_key.execute(hdr.cache_#.addr);
}

@stage(#)
Register<bit<32>, bit<32>>(32w<register_size>) heap_#_value;

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_#_value) heap_#_read_value = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
    }
};

action memory_#_read_value() {
    hdr.cache_#.value = heap_#_read_value.execute(hdr.cache_#.addr);
}