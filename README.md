# ActiveRMT: A framework for running active programs on programmable switches
ActiveRMT enables running active programs on programmable switches based on the portable switch architecture (PSA). Currently, we support Tofino switches (TNA) as our only target. This repository contains the tools necessary to write user-defined applications that can take advantage of memory and compute on programmable switches. This repository contains the following:
1. A runtime for Tofino that can run active programs.
2. A DPDK library to write active applications.

## Requirements
The following hardware and software requirements must be met:
1. A Tofino ASIC is required to run the ActiveRMT runtime (Tofino model may also be used as a virtual switch). The ASIC must be connected to an on-board switch CPU. You will also need to obtain the necessary SDK from Intel to compile and run the P4 code.
2. A DPDK capable NIC (http://core.dpdk.org/supported/nics/) for running active network applications.
3. An x86/x64 platform that supports DPDK. We have tested this on Linux (Ubuntu server 20.04 LTS).
4. DPDK (https://doc.dpdk.org/guides/index.html).
5. Python (https://www.python.org/).

## Getting Started
### Setting up the switch
We assume that you have a Tofino switch configured according to the vendor specifications, and at least one x86 machine connected to one of the switch ports. The software has been tested on SDE 9.7.0 and we recommend using the same for the evaluation. Ensure that the environment variables *SDE* and *SDE_INSTALL* are set correctly. Clone the repository on the switch CPU. You will need the contents of the "activermt" folder on the switch. A set of utility scripts used below can be found in the *$SDE* directory or provided by the vendor.

Compile the P4 program *active.p4*. Run the driver, load the active program onto the switch ASIC (the name of the program is "active") and configure the ports. Assuming you have the scripts "p4_build.sh" and "run_switchd.sh", the following are the sequence of operations you need to perform:

```
<path_to_p4_build.sh> active.p4 P4FLAGS="-Xp4c=--traffic-limit=80"
<path_to_run_switchd.sh> -p active
```

The dataplane is now ready to run active programs. Next, you need to run the controller to enable stateful applicartions. Our controller uses the BFRT Python APIs to interact with the dataplane. Assuming you have a script named "run_bfshell.sh", run the following command:
```
<path_to_run_bfshell.sh> -b <path_to_controller.py> -i
```

The controller is now ready to admit new applications.
