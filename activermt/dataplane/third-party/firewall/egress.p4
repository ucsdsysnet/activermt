// Adapted from p4lang/tutorials.

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// No additional header definitions.
// No additional parser definitions.
// No additional checksum verifications.

/**
    Use pre-defined header names for Internet Protocol headers.
*/

control MyEgress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    // <control-def>
    // </control-def>
    apply { 
        // <control-flow>
        // </control-flow>
    }
}

// No deparser definitions.
// No pipeline definitions.