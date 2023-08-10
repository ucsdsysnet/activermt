state parse_cache_# {
    pkt.extract(hdr.cache_#);
    transition accept;
}