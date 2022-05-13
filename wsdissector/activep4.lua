local proto_activep4 = Proto.new("activep4", "ActiveP4: Initial Header")
local proto_active_program = Proto.new("active_program", "ActiveP4: Active Program")

local field_signature = ProtoField.uint32("activep4.SIG", "ActiveP4SIG", base.HEX)
local field_flags = ProtoField.uint16("activep4.flags", "Flags", base.HEX)
local field_fid = ProtoField.uint16("activep4.fid", "FID", base.DEC)
local field_seq = ProtoField.uint16("activep4.seq", "SEQ", base.DEC)
local field_acc = ProtoField.uint16("activep4.acc", "ACC", base.DEC)
local field_acc2 = ProtoField.uint16("activep4.acc2", "ACC2", base.DEC)
local field_data = ProtoField.uint16("activep4.data", "DATA", base.DEC)
local field_data2 = ProtoField.uint16("activep4.data2", "DATA2", base.DEC)
local field_res = ProtoField.uint16("activep4.res", "RES", base.HEX)

proto_activep4.fields = {field_signature, field_flags, field_fid, field_seq, field_acc, field_acc2, field_data, field_data2, field_res}

function proto_activep4.dissector(buffer, pinfo, tree)
    
    pinfo.cols.protocol = "ActiveP4"
    
    local payload_tree = tree:add( proto_activep4, buffer() )

    payload_tree:add(field_signature, buffer(0, 4))
    payload_tree:add(field_flags, buffer(4, 2))
    payload_tree:add(field_fid, buffer(6, 2))
    payload_tree:add(field_seq, buffer(8, 2))
    payload_tree:add(field_acc, buffer(10, 2))
    payload_tree:add(field_acc2, buffer(12, 2))
    payload_tree:add(field_data, buffer(14, 2))
    payload_tree:add(field_data2, buffer(16, 2))
    payload_tree:add(field_res, buffer(18, 2))

    local flags = buffer(4, 2):uint()
    local buffer_remainder = buffer:range(20, buffer:len() - 20):tvb()

    if (bit.band(flags, 0x0100)) == 0
    then
        proto_active_program.dissector:call(buffer_remainder, pinfo, tree)
    else
        DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
    end
end

local MAX_INSTR = 28
local field_active_instruction = {}
for i = 1,MAX_INSTR do
    field_active_instruction[i] = ProtoField.string(string.format("active_program.instruction_%d", i), string.format("Instruction[%d]", i), base.ASCII)
end

proto_active_program.fields = field_active_instruction

function proto_active_program.dissector(buffer, pinfo, tree)
    
    pinfo.cols.protocol = "Active Program"
    
    local payload_tree = tree:add( proto_active_program, buffer() )

    local program_len = 0

    for i = 1,MAX_INSTR do
        program_len = program_len + 4
        local offset = (i - 1) * 4
        local opcode = buffer(offset + 1, 1):uint()
        payload_tree:add(field_active_instruction[i], string.format("[0x%x] OPCODE=%d (%d)", buffer(offset, 1):uint(), opcode, buffer(offset + 2, 2):uint()))
        if opcode == 0
        then
            break
        end
    end

    local buffer_remainder = buffer:range(program_len, buffer:len() - program_len):tvb()
    DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
end

eth_table = DissectorTable.get("ethertype"):add(0x83b2, proto_activep4)