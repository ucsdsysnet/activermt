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

action get_allocation_s<stage-id>(bit<32> offset, bit<32> size) {
    hdr.alloc[<instruction-id>].offset = offset;
    hdr.alloc[<instruction-id>].size = size;
}

table allocation_<stage-id> {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s<stage-id>;
    }
}