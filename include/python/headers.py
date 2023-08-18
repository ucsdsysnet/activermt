#    Copyright 2023 Rajdeep Das, University of California San Diego.

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#        http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

from scapy.all import *

class ActiveInitialHeader(Packet):
    name = "ActiveInitialHeader"
    fields_desc = [
        IntField("ACTIVEP4", 0x12345678),
        ShortField("flags", 0),
        ShortField("fid", 0),
        ShortField("seq", 0)
    ]

class ActiveArguments(Packet):
    name = "ActiveArguments"
    fields_desc = [
        IntField("data_0", 0),
        IntField("data_1", 0),
        IntField("data_2", 0),
        IntField("data_3", 0)
    ]
    def guess_payload_class(self, payload):
        return ActiveInstruction

class ActiveInstructionHeader(Packet):
    name = "ActiveInstructionHeader"
    fields_desc = [
        ByteField("goto", 0), # also has flags
        ByteField("opcode", 0)
    ]
    def guess_payload_class(self, payload):
        if self.opcode == 0:
            return IP
        else:
            return ActiveInstructionHeader

class ActiveMalloc(Packet):
    name = "ActiveMalloc"
    fields_desc = [
        ShortField("proglen", 0),
        ByteField("iglim", 0),
        ByteField("mem_0", 0),
        ByteField("mem_1", 0),
        ByteField("mem_2", 0),
        ByteField("mem_3", 0),
        ByteField("mem_4", 0),
        ByteField("mem_5", 0),
        ByteField("mem_6", 0),
        ByteField("mem_7", 0),
        ByteField("dem_0", 0),
        ByteField("dem_1", 0),
        ByteField("dem_2", 0),
        ByteField("dem_3", 0),
        ByteField("dem_4", 0),
        ByteField("dem_5", 0),
        ByteField("dem_6", 0),
        ByteField("dem_7", 0)
    ]

class ActiveAlloc(Packet):
    name = "ActiveAllocation"
    fields_desc = [
        ShortField("start_0", 0),
        ShortField("end_0", 0),
        ShortField("start_1", 0),
        ShortField("end_1", 0),
        ShortField("start_2", 0),
        ShortField("end_2", 0),
        ShortField("start_3", 0),
        ShortField("end_3", 0),
        ShortField("start_4", 0),
        ShortField("end_4", 0),
        ShortField("start_5", 0),
        ShortField("end_5", 0),
        ShortField("start_6", 0),
        ShortField("end_6", 0),
        ShortField("start_7", 0),
        ShortField("end_7", 0),
        ShortField("start_8", 0),
        ShortField("end_8", 0),
        ShortField("start_9", 0),
        ShortField("end_9", 0),
        ShortField("start_10", 0),
        ShortField("end_10", 0),
        ShortField("start_11", 0),
        ShortField("end_11", 0),
        ShortField("start_12", 0),
        ShortField("end_12", 0),
        ShortField("start_13", 0),
        ShortField("end_13", 0),
        ShortField("start_14", 0),
        ShortField("end_14", 0),
        ShortField("start_15", 0),
        ShortField("end_15", 0),
        ShortField("start_16", 0),
        ShortField("end_16", 0),
        ShortField("start_17", 0),
        ShortField("end_17", 0),
        ShortField("start_18", 0),
        ShortField("end_18", 0),
        ShortField("start_19", 0),
        ShortField("end_19", 0)
    ]

bind_layers(Ether, ActiveInitialHeader, type=0x83b2)
bind_layers(ActiveInitialHeader, ActiveArguments, flags=0x8000)
bind_layers(ActiveInitialHeader, ActiveArguments, flags=0x8100)
bind_layers(ActiveInitialHeader, ActiveInstructionHeader, flags=0x0000)
bind_layers(ActiveInitialHeader, ActiveMalloc, flags=0x0020)
bind_layers(ActiveInitialHeader, ActiveAlloc, flags=0x0028)
bind_layers(ActiveInitialHeader, IP, flags=0x0010)
split_layers(ActiveInstructionHeader, IP, opcode=0)
split_layers(IP, TCP, proto=6)