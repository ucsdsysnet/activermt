//    Copyright 2023 Rajdeep Das, University of California San Diego.

//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at

//        http://www.apache.org/licenses/LICENSE-2.0

//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

action get_allocation_s<stage-id>(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[<instruction-id>].setValid();
    hdr.alloc[<instruction-id>].offset = offset_ig;
    hdr.alloc[<instruction-id>].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].size = size_eg;
}

action default_allocation_s<stage-id>() {
    hdr.alloc[<instruction-id>].setValid();
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].setValid();
}

table allocation_<stage-id> {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s<stage-id>;
        default_allocation_s<stage-id>;
    }
    //default_action = default_allocation_s<stage-id>;
}