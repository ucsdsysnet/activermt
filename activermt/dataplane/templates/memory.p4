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

Register<bit<32>, bit<32>>(32w94208) heap_s<stage-id>;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_write_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_increment_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_read_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_write_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_accumulate_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_rw_max_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_rw_zero_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_conditional_increment_s<stage-id> = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s<stage-id>) heap_bulk_write_s<stage-id> = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_<data-id>;
    }
};*/