# ActiveRMT: A framework for running active programs on programmable switches
ActiveRMT enables running active programs on programmable switches based on the Tofino Native Architecture (TNA). This repository contains the tools necessary to write user-defined applications that can take advantage of memory and compute on Tofino switches. This repository contains the following:
1. Control plane and data plane software to run active programs.
2. A DPDK library to write user-space active applications.
3. A Linux shim layer to enable POSIX-socket based active applications.

## Getting Started
### Minimum Requirements
At the very least, you would need to obtain the Intel SDK (https://www.intel.com/content/www/us/en/products/details/network-io/intelligent-fabric-processors/p4-studio.html) to be able to compile and run P4 dataplane and control plane code. You would also need a Linux (x86) machine to evaluate the system.

### Setting up ActiveRMT
We will use a default routing configuration to test ActiveRMT on the Tofino model emulator. The routing configurations are located at "config/". Routing tables have the format "ip_config_<id>.csv", where <id> refers to a routing configuration (e.g. model).

Perform the following steps to get ActiveRMT running on the Tofino model:
1. Install the SDK according to Intel documentation. You should have the *SDE* variable set correctly post installation. You should also have a set of utility scripts installed at the *SDE* location or provided by Intel.
2. Build the P4 source for ActiveRMT.
```
cd activermt/dataplane
$SDE/p4_build.sh active.p4 P4FLAGS="-Xp4c=--traffic-limit=80"
```
3. Run the Tofino model.
```
cd $SDE
run_tofino_model.sh -p active
```
4. Run the driver.
```
cd $SDE
run_switchd.sh -p active
```
The ActiveRMT dataplane is now ready to run active programs. However, it still needs to be configured with the instruction set so that programs are correctly recognized.
5. Run a PTF test to install a minimal runtime and test the system. The test runs a "NOP" program (activermt/tests/nop/nop.ap4) that runs a dummy program to check execution at the switch. Upon execution of the program, a flag is set in the ActiveRMT Initial Header to indicate the same. The packet is routed according to the default routing table.
```
cd <activermt_source_dir>/activermt/tests
$SDE/run_p4_tests.sh -p active -t nop/
```
If the test passes, then the ActiveRMT dataplane is set up correctly. Feel free to play around with the test framework to run more complex tests.

## Running an application
Now that we have tested a working ActiveRMT, we can write an active application for an activated switch. Note that you will require a Tofino ASIC for the rest of this document. If you do not have one, you may be able to create a virtual switch using the Tofino model running on a x86 machine. This document does not however, cover the details of how to do so.

### Requirements
The following hardware and software requirements must be met:
1. A Tofino ASIC.
2. Intel SDK for Tofino.
3. A DPDK capable NIC (http://core.dpdk.org/supported/nics/) for running active network applications.
4. DPDK (https://doc.dpdk.org/guides/index.html).
5. A Linux (x86) machine, preferrably running Ubuntu (focal or higher).

### Setting up the ASIC
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

The examples folder contains applications that use the active runtime. Before we evaluate stateful applications such as a key-value store, let's run a stateless application based on DPDK. Make sure that DPDK is installed and the environment variables set correctly.

### A stateless application: ping
The "examples/ping/activesrc" folder contains the active program for our ping application. The program simply echoes the packet to the ingress port while swapping the Ethernet and IP addresses. Such an utility can be useful in measuring network congestion. 

A DPDK application that measures ping times to the switch is located at the "examples/ping/app/dpdk" folder. First, build the application by running `make` inside the folder. A helper script "launch.sh" is also present in the directory which launches the application. Quit the application after some time pressing "Ctrl+C". A CSV file containing measured ping times should be present in the same folder. Run the plotter script by typing `./plotter.py`. A CDF (png) plot of the ping times should be generated in the same folder. 
