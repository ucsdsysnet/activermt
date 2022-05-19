CRCPolynomial<bit<16>>(
    coeff       = <poly-param-coeff>,
    reversed    = <poly-param-reversed>,
    msb         = false,
    extended    = false,
    init        = <poly-param-init>,
    xor         = <poly-param-xor>
) crc_16_poly_s<stage-id>;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s<stage-id>) crc_16_s<stage-id>;