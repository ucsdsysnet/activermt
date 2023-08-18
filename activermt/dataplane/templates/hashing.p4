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

CRCPolynomial<bit<16>>(
    coeff       = <poly-param-coeff>,
    reversed    = <poly-param-reversed>,
    msb         = false,
    extended    = true,
    init        = <poly-param-init>,
    xor         = <poly-param-xor>
) crc_16_poly_s<stage-id>;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s<stage-id>) crc_16_s<stage-id>;