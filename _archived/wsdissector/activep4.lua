local proto_activep4 = Proto.new("activep4", "ActiveP4: Initial Header")
local proto_active_malloc_req = Proto.new("active_malloc_req", "ActiveP4: Malloc Request")
local proto_active_alloc = Proto.new("active_alloc", "ActiveP4: Memory Allocation")
local proto_active_program = Proto.new("active_program", "ActiveP4: Active Program")

local field_signature = ProtoField.uint32("activep4.SIG", "ActiveP4SIG", base.HEX)
local field_flags = ProtoField.uint16("activep4.flags", "Flags", base.HEX)
local field_fid = ProtoField.uint16("activep4.fid", "FID", base.DEC)
local field_seq = ProtoField.uint16("activep4.seq", "SEQ", base.DEC)

proto_activep4.fields = {field_signature, field_flags, field_fid, field_seq}

local field_active_proglen = ProtoField.uint16("activep4malloc.proglen", "PROGLEN", base.DEC)
local field_active_iglim = ProtoField.uint8("activep4malloc.iglim", "IGLIM", base.DEC)
local field_active_memid = {}
local field_active_demand = {}

proto_active_malloc_req.fields = {field_active_proglen, field_active_iglim}

proto_active_alloc.fields = {}

local field_active_alloc_stage = {}

local NUM_STAGES = 20
for i = 1,NUM_STAGES do
    field_active_alloc_stage[i] = ProtoField.string(string.format("activep4alloc.stage_%d", i), string.format("stage_%d", i), base.ASCII)
    table.insert(proto_active_alloc.fields, field_active_alloc_stage[i])
end

local MAX_MEMIDX = 8
for i = 1,MAX_MEMIDX do
    field_active_memid[i] = ProtoField.uint8(string.format("activep4malloc.mem_%d", i), string.format("mem_%d", i), base.DEC)
    table.insert(proto_active_malloc_req.fields, field_active_memid[i])
end
for i = 1,MAX_MEMIDX do
    field_active_demand[i] = ProtoField.uint8(string.format("activep4malloc.dem_%d", i), string.format("dem_%d", i), base.DEC)
    table.insert(proto_active_malloc_req.fields, field_active_demand[i])
end

local MAX_ARGS = 4
local field_active_arg = {}
for i = 1,MAX_ARGS do
    field_active_arg[i] = ProtoField.uint32(string.format("activep4.arg_%d", i), string.format("Argument[%d]", i), base.HEX)
    table.insert(proto_activep4.fields, field_active_arg[i])
end

function proto_activep4.dissector(buffer, pinfo, tree)
    
    pinfo.cols.protocol = "ActiveP4"
    
    local payload_tree = tree:add( proto_activep4, buffer() )

    payload_tree:add(field_signature, buffer(0, 4))
    payload_tree:add(field_flags, buffer(4, 2))
    payload_tree:add(field_fid, buffer(6, 2))
    payload_tree:add(field_seq, buffer(8, 2))

    local flags = buffer(4, 2):uint()
    local buffer_remainder = buffer:range(10, buffer:len() - 10):tvb()

    if (bit.band(flags, 0x8000)) > 0
    then
        for i = 1,MAX_ARGS do
            local offset = (i - 1) * 4
            payload_tree:add(field_active_arg[i], string.format("0x%x", buffer_remainder(offset, 4):uint()))
        end
        buffer_remainder = buffer_remainder:range(16, buffer_remainder:len() - 16):tvb()
    end

    if (bit.band(flags, 0x0010)) > 0
    then
        proto_active_malloc_req.dissector:call(buffer_remainder, pinfo, tree)
    elseif (bit.band(flags, 0x0008)) > 0
    then
        proto_active_alloc.dissector:call(buffer_remainder, pinfo, tree)
    elseif (bit.band(flags, 0x0020)) > 0
    then
        DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
    elseif (bit.band(flags, 0x0100)) == 0
    then
        proto_active_program.dissector:call(buffer_remainder, pinfo, tree)
    else
        DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
    end
end

function proto_active_malloc_req.dissector(buffer, pinfo, tree)

    pinfo.cols.protocol = "Active Malloc Request"

    local payload_tree = tree:add( proto_active_malloc_req, buffer() )

    payload_tree:add(field_active_proglen, buffer(0, 2))
    payload_tree:add(field_active_iglim, buffer(2, 1))

    local buffer_remainder = buffer:range(3, buffer:len() - 3):tvb()

    for i = 1,MAX_MEMIDX do
        payload_tree:add(field_active_memid[i], string.format("%d", buffer_remainder(i - 1, 1):uint()))
    end
    buffer_remainder = buffer_remainder:range(8, buffer_remainder:len() - 8):tvb()

    for i = 1,MAX_MEMIDX do
        payload_tree:add(field_active_demand[i], string.format("%d", buffer_remainder(i - 1, 1):uint()))
    end
    buffer_remainder = buffer_remainder:range(8, buffer_remainder:len() - 8):tvb()

    DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
end

function proto_active_alloc.dissector(buffer, pinfo, tree)

    pinfo.cols.protocol = "Active Memory Allocation"

    local payload_tree = tree:add( proto_active_alloc, buffer() )

    for i = 1,NUM_STAGES do
        local offset = (i - 1) * 4
        local mem_start = buffer(offset, 2):uint()
        local mem_end = buffer(offset + 2, 2):uint()
        payload_tree:add(field_active_alloc_stage[i], string.format("%d - %d", mem_start, mem_end))
    end

    buffer_remainder = buffer:range(80, buffer:len() - 80):tvb()

    DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
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
        program_len = program_len + 2
        local offset = (i - 1) * 2
        local opcode = buffer(offset + 1, 1):uint()
        payload_tree:add(field_active_instruction[i], string.format("[0x%x] OPCODE=%d", buffer(offset, 1):uint(), opcode))
        if opcode == 0
        then
            break
        end
    end

    local buffer_remainder = buffer:range(program_len, buffer:len() - program_len):tvb()
    DissectorTable.get("ethertype"):get_dissector(0x0800):call(buffer_remainder, pinfo, tree)
end

eth_table = DissectorTable.get("ethertype"):add(0x83b2, proto_activep4)