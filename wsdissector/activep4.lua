local proto_activeswitch = Proto.new("activeswitch", "ActiveSwitch")
local proto_activeinstruction = Proto.new("activeinstruction", "ActiveInstruction")

local field_padding = ProtoField.uint64("activeswitch.padding", "Padding", base.HEX)
local field_timestamp = ProtoField.uint64("activeswitch.timestamp", "Timestamp", base.DEC)
local field_tsmagic = ProtoField.string("activeswitch.tsmagic", "TS Magic")
local field_flags = ProtoField.uint16("activeswitch.flags", "Flags", base.HEX)
local field_fid = ProtoField.uint16("activeswitch.fid", "FID", base.DEC)
local field_acc = ProtoField.uint16("activeswitch.acc", "ACC", base.DEC)
local field_acc2 = ProtoField.uint16("activeswitch.acc2", "ACC2", base.DEC)
local field_id = ProtoField.uint16("activeswitch.id", "Key", base.DEC)
local field_freq = ProtoField.uint16("activeswitch.freq", "Frequency", base.DEC)

proto_activeswitch.fields = {field_padding, field_timestamp, field_tsmagic, field_flags, field_fid, field_acc, field_acc2, field_id, field_freq}

local field_goto = ProtoField.uint8("activeinstruction.goto", "Flags/Goto", base.HEX)
local field_opcode = ProtoField.uint8("activeinstruction.opcode", "OPCODE", base.DEC)
local field_arg = ProtoField.uint16("activeinstruction.arg", "Argument", base.DEC)

proto_activeinstruction.fields = {field_goto, field_opcode, field_arg}

function proto_activeswitch.dissector(buffer, pinfo, tree)
    
    pinfo.cols.protocol = "Active Switch"
    
    local payload_tree = tree:add( proto_activeswitch, buffer() )

--    local padding_pos = 0
--    local padding_len = 6
--    local padding_buffer = buffer(padding_pos, padding_len)
--    payload_tree:add(field_padding, padding_buffer)

    local timestamp_pos = 6
    local timestamp_len = 8
    local timestamp_buffer = buffer(timestamp_pos, timestamp_len)
    payload_tree:add(field_timestamp, timestamp_buffer)

    local magic_pos = 14
    local magic_len = 2
    local magic_buffer = buffer(magic_pos, magic_len)
    payload_tree:add(field_tsmagic, magic_buffer)

    local flags_pos = 16
    local flags_len = 2
    local flags_buffer = buffer(flags_pos, flags_len)
    payload_tree:add(field_flags, flags_buffer)

    local fid_pos = 18
    local fid_len = 2
    local fid_buffer = buffer(fid_pos, fid_len)
    payload_tree:add(field_fid, fid_buffer)

    local acc_pos = 20
    local acc_len = 2
    local acc_buffer = buffer(acc_pos, acc_len)
    payload_tree:add(field_acc, acc_buffer)

    local acc2_pos = 22
    local acc2_len = 2
    local acc2_buffer = buffer(acc2_pos, acc2_len)
    payload_tree:add(field_acc2, acc2_buffer)

    local id_pos = 24
    local id_len = 2
    local id_buffer = buffer(id_pos, id_len)
    payload_tree:add(field_id, id_buffer)

    local freq_pos = 26
    local freq_len = 2
    local freq_buffer = buffer(freq_pos, freq_len)
    payload_tree:add(field_freq, freq_buffer)
end

function proto_activeinstruction.dissector(buffer, pinfo, tree)
    
    pinfo.cols.protocol = "Active Instruction"
    
    local payload_tree = tree:add( proto_activeinstruction, buffer() )

    local goto_pos = 0
    local goto_len = 1
    local goto_buffer = buffer(goto_pos, goto_len)
    payload_tree:add(field_goto, goto_buffer)

    local opcode_pos = 1
    local opcode_len = 1
    local opcode_buffer = buffer(opcode_pos, opcode_len)
    payload_tree:add(field_opcode, opcode_buffer)

    local arg_pos = 2
    local arg_len = 2
    local arg_buffer = buffer(arg_pos, arg_len)
    payload_tree:add(field_arg, arg_buffer)
end

udp_table = DissectorTable.get("udp.port"):add(9877, proto_activeswitch)