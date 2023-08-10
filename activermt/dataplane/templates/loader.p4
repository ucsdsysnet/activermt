action load_instr_#(bit<8> opcode, bit<1> goto) {
    hdr.instr[#].opcode = opcode;
    hdr.instr[#].goto = goto;
}

table loader_# {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_#;
    }
}