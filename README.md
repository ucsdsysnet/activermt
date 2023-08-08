# ActiveRMT Source

Source code for the ActiveRMT project. Contains the following main components:

1. P4 program(s) for the runtime that runs active programs embedded in network packets.
2. Client interface(s) for the runtime.
3. Applications (and corresponding clients) that have been written for the active runtime.

## Dataplane (P4-16)
Dataplane source is located at "p416/". The file "generate.py" is used to generate the P4 source based on templates and configurations. The main P4 file is "active.p4".

## Controller (Python)
The controller code is contained in the file "bfrt/ctrl/controller.py". This also uses "allocator.py" located at "malloc/".

## Active Programs (Active Instruction Set)
Example active programs are located at "apps/<program_name>/active". Associated test clients are located at "apps/<program_name>/clients". These are written in C/C++ or Python. The compiler is located at "compiler/ap4.py".

## Shim Layer (C/C++)
Client shim layers are located at "netproxy/". These are based on DPDK. 

## DPDK Clients (C/C++)
DPDK-based clients for active packet generation is located at "clients/dpdk-client". Clients are written in a framework that simplifies writing active applications. A set of exported interfaces are defined in the corresponding application headers (e.g. "active_cache.h").

## Wireshark Dissectors (Lua)
Dissectors that recognize active packets are located at "wsdissector/".

## Utility scripts (BASH/Python)
There are various utility scripts that can e.g., be used to create virtual networks with the Tofino model to evaluate functionality. These can be found at "util/".  

# SIGCOMM Paper Evaluations
Here are the instructions to generate the following graphs, which can be run on any standard x86/x64 machine:
1. Figure 5(a)
2. Figure 5(b)
3. Figure 6(a)
4. Figure 6(b)
5. Figure 7(a)
6. Figure 7(b)
7. Figure 7(c)
8. Figure 7(d)
9. Figure 11(a)
10. Figure 11(b)
11. Figure 11(c)
12. Figure 11(d)
13. Figure 12(a)
14. Figure 12(b)
15. Figure 12(c)
16. Figure 12(d)

Figures 8,9 and 10 require a Tofino ASIC.
