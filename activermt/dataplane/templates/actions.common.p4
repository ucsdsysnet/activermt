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

/*action uncomplete() {
    hdr.meta.complete = 0;
}*/

action fork() {
    hdr.meta.duplicate = 1;
}

action copy_mbr2_mbr1() {
    hdr.meta.mbr2 = hdr.meta.mbr;
}

action copy_mbr1_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr2;
}

/*action mark_packet() {
    hdr.ih.flag_marked = 1;
}*/

// action memfault() {
//     hdr.ih.flag_mfault = 1;
//     complete();
//     rts();
// }

action min_mbr1_mbr2() {
    hdr.meta.mbr = (hdr.meta.mbr <= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
}

action min_mbr2_mbr1() {
    hdr.meta.mbr2 = (hdr.meta.mbr2 <= hdr.meta.mbr ? hdr.meta.mbr2 : hdr.meta.mbr);
}

action mbr1_equals_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.meta.mbr2;
}

action copy_mar_mbr() {
    hdr.meta.mar = hdr.meta.mbr;
}

action copy_mbr_mar() {
    hdr.meta.mbr = hdr.meta.mar;
}

action copy_inc_mbr() {
    hdr.meta.inc = hdr.meta.mbr;
}

action copy_hash_data_mbr() {
    hdr.meta.hash_data_0 = hdr.meta.mbr;
}

action copy_hash_data_mbr2() {
    hdr.meta.hash_data_1 = hdr.meta.mbr2;
}

action bit_and_mar_mbr() {
    hdr.meta.mar = hdr.meta.mar & hdr.meta.mbr;
}

action mar_add_mbr() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr;
}

action mar_add_mbr2() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr2;
}

action mbr_add_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.meta.mbr2;
}

action mar_mbr_add_mbr2() {
    hdr.meta.mar = hdr.meta.mbr + hdr.meta.mbr2;
}

action load_salt() {
    hdr.meta.mbr = CONST_SALT;
}

action not_mbr() {
    hdr.meta.mbr = ~hdr.meta.mbr;
}

action mbr_or_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr | hdr.meta.mbr2;
}

action mbr_subtract_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr - hdr.meta.mbr2;
}

action swap_mbr_mbr2() {
    bit<32> tmp;
    tmp = hdr.meta.mbr;
    hdr.meta.mbr = hdr.meta.mbr2;
    hdr.meta.mbr2 = tmp;
}

action max_mbr_mbr2() {
    hdr.meta.mbr = (hdr.meta.mbr >= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
}

/*action addr_mask_apply() {
    hdr.meta.mar = hdr.meta.mar & hdr.meta.paddr_mask;
}*/

/*action addr_offset_apply() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.paddr_offset;
}*/

action addr_mask_apply(bit<32> addr_mask) {
    hdr.meta.mar = hdr.meta.mar & addr_mask;
}

action addr_offset_apply(bit<32> offset) {
    hdr.meta.mar = hdr.meta.mar + offset;
}

action mar_load() {
    hdr.meta.mar = hdr.data.data_0 & 0xFFFFF;
}

action mbr_load() {
    hdr.meta.mbr = hdr.data.data_1;
}

action mbr2_load() {
    hdr.meta.mbr2 = hdr.data.data_2;
}

action mbr_store() {
    hdr.data.data_3 = hdr.meta.mbr;
}

action mbr_store_alt() {
    hdr.data.data_1 = hdr.meta.mbr;
}

action mbr_store_alt_2() {
    hdr.data.data_2 = hdr.meta.mbr;
}

// action mbr_store_extended_data_0() {
//     hdr.extended_data[0].data = hdr.meta.mbr;
//     // hdr.extended_data[0].setValid();
// }

// action mbr_store_extended_data_1() {
//     hdr.extended_data[1].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_2() {
//     hdr.extended_data[2].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_3() {
//     hdr.extended_data[3].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_4() {
//     hdr.extended_data[4].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_5() {
//     hdr.extended_data[5].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_6() {
//     hdr.extended_data[6].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_7() {
//     hdr.extended_data[7].data = hdr.meta.mbr;
// }