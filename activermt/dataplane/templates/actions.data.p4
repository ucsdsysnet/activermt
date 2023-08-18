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

// action mar_load_d<data-id>() {
//     hdr.meta.mar = hdr.data.<data> & 0xFFFFF;
// }

// action mbr_load_d<data-id>() {
//     hdr.meta.mbr = hdr.data.<data>;
// }

// action mbr2_load_d<data-id>() {
//     hdr.meta.mbr2 = hdr.data.<data>;
// }

// action d<data-id>_load_mbr() {
//     hdr.data.<data> = hdr.meta.mbr;
// }

// action addrmap_load_d<data-id>() {
//     hdr.meta.paddr_mask = hdr.data.<data>;
//     hdr.meta.paddr_offset = hdr.data.<data> >> 16;
// }

action mbr_equals_d<data-id>() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.<data>;
}