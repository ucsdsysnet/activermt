register bloom_meter {
    width           : 8;
    instance_count  : 65536;
}

blackbox stateful_alu bloom_meter_filter {
    reg                     : bloom_meter;
    condition_lo            : register_lo == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 1;
    output_predicate        : condition_lo;
    output_dst              : meta.digest;
    output_value            : 1;
}

action dofilter_meter() {
    bloom_meter_filter.execute_stateful_alu(as.fid);
}

table filter_meter {
    reads {
        meta.color          : exact;
    }
    actions {
        dofilter_meter;
    }
}

meter function_meter {
    type            : bytes;
    direct          : resources;
    result          : meta.color;
}

field_list meter_params {
    as.fid;
    meta.color;
}

action report() {
    generate_digest(0, meter_params);
}

table monitor {
    reads {
        meta.digest : exact;
    }
    actions {
        report;
    }
}