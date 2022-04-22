--------------------------------------------------------------
-- Wireshark dissectors for Intel Connectivity Academy headers
--
-- The file ~/.local/lib/wireshark/plugins/ica-dissectors.lua
-- should be a symlink to ~/tools/ica-dissectors.lua
--------------------------------------------------------------

--
-- 15 - simple_lpf
--
lpf_protocol = Proto("LPF", "Simple LPF Protocol")

input    = ProtoField.uint32("lpf.input",    "input",    base.DEC)
output_1 = ProtoField.uint32("lpf.output_1", "output_1", base.DEC)
output_2 = ProtoField.uint32("lpf.output_2", "output_2", base.DEC)
output_3 = ProtoField.uint32("lpf.output_3", "output_3", base.DEC)

lpf_protocol.fields = {input, output_1, output_2, output_3}

function lpf_protocol.dissector(buffer, pinfo, tree)
   length = buffer:len()
   if length < 16 then return end

   pinfo.cols.protocol = lpf_protocol.name

   local subtree = tree:add(lpf_protocol, buffer(),
                            "LPF Protocol Data")

   subtree:add(input,    buffer( 0, 4))
   subtree:add(output_1, buffer( 4, 4))
   subtree:add(output_2, buffer( 8, 4))
   subtree:add(output_3, buffer(12, 4))
end

local ether_type = DissectorTable.get("ethertype")
ether_type:add(0xD011, lpf_protocol)

--
-- 16 - simple_wred
--
wred_protocol = Proto("WRED", "Simple WRED Protocol")

input    = ProtoField.uint32("wred.input",   "input",    base.DEC)
output   = ProtoField.uint8 ("wred.output",  "output",   base.DEC,
                             { [0] = "No Drop"; [1] = "Drop" })

wred_protocol.fields = {input, output}

function wred_protocol.dissector(buffer, pinfo, tree)
   length = buffer:len()
   if length < 5 then return end

   pinfo.cols.protocol = lpf_protocol.name

   local subtree = tree:add(wred_protocol, buffer(),
                            "WRED Protocol Data")

   subtree:add(input,  buffer( 0, 4))
   subtree:add(output, buffer( 4, 1))
end

local ether_type = DissectorTable.get("ethertype")
ether_type:add(0xD012, wred_protocol)

--
-- 30-p4calc
--
p4calc_protocol = Proto("P4calc", "P4 Calculator Protocol")

p4      = ProtoField.string("p4calc.p4",      "p4", "Protocol Signature")
version = ProtoField.uint8 ("p4calc.version", "version")
op      = ProtoField.string("p4calc.op",      "op")
operA   = ProtoField.uint32("p4calc.a",       "operA")
operB   = ProtoField.uint32("p4calc.b",       "operB")
result  = ProtoField.uint32("p4calc.res",     "result")

p4calc_protocol.fields = {p4, version, op, operA, operB, result}

function p4calc_protocol.dissector(buffer, pinfo, tree)
   length = buffer:len()
   if length < 16 then return end

   pinfo.cols.protocol = p4calc_protocol.name
   local subtree = tree:add(p4calc_protocol, buffer(),
                            "P4Calc Protocol Data")

   subtree:add(p4,      buffer( 0, 2))
   subtree:add(version, buffer( 2, 1))
   subtree:add(op,      buffer( 3, 1))
   subtree:add(operA,   buffer( 4, 4))
   subtree:add(operB,   buffer( 8, 4))
   subtree:add(result,  buffer(12, 4))
end
local ether_type = DissectorTable.get("ethertype")
ether_type:add(0x1234, p4calc_protocol)

      
--
-- 40-dead_drop
--
dead_drop_protocol = Proto("DeadDrop", "DeadDrop Protocol")

box_num   = ProtoField.uint16("dead_drop.box_num",   "Mailbox#",    base.DEC)
box_op    = ProtoField.uint16("dead_drop.box_op",    "Operation",   base.DEC,
                              {
                                 [0] = "DROPOFF";
                                 [1] ="PICKOFF"
                              })
data_dest = ProtoField.uint16("dead_drop.data_dest", "Dest. Port",  base_DEC)
box_data  = ProtoField.bytes( "dead_drop.box_data",  "Secret Data", base.SPACE)

dead_drop_protocol.fields = {box_num, box_op, data_dest, box_data}

function dead_drop_protocol.dissector(buffer, pinfo, tree)
   if buffer:len() < 10 then return end

   pinfo.cols.protocol = dead_drop_protocol.name

   local subtree = tree:add(dead_drop_protocol, buffer(),
                            "DeadDrop Protocol")

   subtree:add(box_num,   buffer(0, 2))
   subtree:add(box_op,    buffer(2, 2))
   subtree:add(data_dest, buffer(4, 2))
   subtree:add(box_data,  buffer(6, 4))
end

DissectorTable.get("ethertype"):add(0xDEAD, dead_drop_protocol)
