#!/bin/bash

#
# p4_build.sh
#
# This script utilizes p4-build system to build user's P4 program within
# the framework of the chosen SDE
#
# Directory Organization:
#
# $P4_PATH ---> points to the "main" p4 file that constitutes user program
#
# Recommended organization of user directories:
#
# $YOUR_DIR \
#    p4src     -- P4 code
#    ptf-tests -- PTF tests
#
# $SDE \
#    build/p4-build$P4_NAME -- p4-build directory for the program
#    logs/p4-build/$P4_NAME  -- log files for the build    
#    install             -- programs are installed according to p4-build
#
# The build should be done using the tools in $SDE and $SDE_INSTALL
# Similarly, when test is going to be run, the model, the drivers, PTF, etc. 
# should be coming from $SDE and $SDE_INSTALL
#

#
# Just stop if there is any problem
#
set -e

# Uncomment the line below for debug purposes
#set -x

p4src=p4src
ptf=ptf-tests

packages=packages         # The SDE subdirectory SDE where package tarballs are
pkgsrc=pkgsrc             # The SDE subdirectory, where tarbals are untarred
build=build               # The SDE subdirectory, where the builds are done
logs=logs                 # The SDE subdirectory, where build logs are stored
install=install

sde_min_gb=4              # We recommend at least 4GB RAM for SDE build
log_lines=15              # How many lines from the log to show on error

default_p4flags="-g"

#
# The following parameters are controlled through the command line
#
jobs=0                          # Number of jobs to run in parallel (0 is auto)
with_tofino="--with-tofino"     # Compile for Tofino/Tofino-model
with_tofinobm=""                # Compile for BMv2-Tofino
with_bmv2=""                    # Compile for BMv2-simple_switch
with_thrift="--enable-thrift"   # Build Thrift Client/Server Code
with_graphs=1                   # Build p4-graphs

#
# The following parameters depend on the toolchain and the language dialect
# you are mostly working with
#

# "Classic" p4c-tofino compiler and p4-hir based tools. P4_14 only
with_p4c="bf-p4c"           # Default compiler to use (p4c
with_p4graphs="p4-graphs"       # Default p4 graphs tool
p4version=14                    # I work with P4_14 for now
default_p4flags="-g"            # extra P4FLAGS

# "New" p4c compiler and tools. P4_14 (P4_16 later)
#with_p4c="p4c"
#with_p4graphs="p4c-graphs"
#p4version=14
#p4flags="-g"

print_help() {
    cat <<EOF

Usage: p4_build.sh [options] <p4-program> [p4-build-vars] [-- <p4-build-flags>]"

Supported options:
  General:
  ========
    -h, --help    -- Print this help
    -v, --version -- Print this script version
    -j jobs       -- Specify maximum jobs for parallelization. Default is 0,
                     meaning that the script will determine the optimal value
                     automatically

    --with-graphs -- Automatically invoke p4-graphs to build the parser, flow
                     and dependency graphs (this is the default)
    --without-graphs Do not automatically invoke p4-graphs

    --with-thrift -- Automatically generate Thrift bindings and Thrift server
                     for PD APIs (this is the default)
    --without-thrift Do not automatically generate Thrift bindings and server

    --p4flags="<additional compiler flags>"
                     Pass additional compiler flags in addition to the default
                     flags. If you need to fully override compiler flags, use
                     P4FLAGS="your compiler flags" instead (see below)

    --with-p4c=<path-to-P4-compiler>
                     You can override the default compiler

    --with-p4graphs=<path-to-P4-graph-generator>
                     You can override the path to P4 graphs generator.

    --p4v 14|16
                     P4 version the program is written in. P4_14 is the (only)
                     default for now
                     
 Platforms:
 ==========
    For each supported platform P, you can specify the following flags:
      --with-P    -- do compile for that platform P 
      --without-P -- do not compile for the platform P (--no-P is an alias)
    Supported platforms are:
      tofino   -- Tofino(tm) ASIC and its register-accurate model (default)
      tofinobm -- BMv2-Based Behavioral Simulator for Tofino (unsupported)
      bmv2     -- BMv2-simple_switch (unsupported)

  Most important P4-Build Variables:
  ==================================
  P4_NAME     Name of the P4 program. By default that's the basename of the 
              file you pass to the script
  P4_PREFIX   Prefix for the PD APIs. By default, that's the basename of the
        

      file you pass to the script
  P4PPFLAGS   Preprocessor flags for P4 program
  P4FLAGS     Compiler flags for p4c-tofino compiler. This will override the 
              default setting
  P4JOBS      The number of p4c-tofino threads (see -j)
  PDFLAGS     Compiler flags for tofino pd generation
  BM_P4FLAGS  Compiler flags for p4c-bmv2 compiler
  P4_BUILD_ASSUME_PDFIXED
              Bypass check for pdfixed headers
  P4C_BM_FLAGS
              Options to pass to the p4c-bmv2 compiler
  CC          C compiler command
  CFLAGS      C compiler flags
  CPP         C preprocessor
  CPPFLAGS    C preprocessofr flags
  CXX         C++ compiler command
  CXXFLAGS    C++ compiler flags
  PYTHON      the Python interpreter
  
  Most important P4-build flags:
  ==============================
  By "flags" we mean parameters that start with "-" or "--". Unlike P4-build
  variables they need to be separated from the rest of the parameters via "--".

  Run "$SDE/pkgsrc/p4-build/configure --help" for the full list 

  Default compiler flags:
  =======================
  P4FLAGS="$default_p4flags"

EOF
}

#
# Print version
#
print_version() {
    echo "Designed for SDE-7.0.1"
}

#
# Autodetecting the number of the CPUs
#
get_ncpus() {
    ncpu=`grep ^processor /proc/cpuinfo | tail -1 | sed -e 's/^.*: //'`
    echo $[ncpu+1]
}


#
# This function makes sure that all "normal" SDE-related variables are there
#
check_environment() {
    if [ -z $SDE ]; then
        echo "WARNING: SDE Environment variable is not set"
        echo "         Assuming $PWD"
        export SDE=$PWD
    else 
        echo "Using SDE ${SDE}"
    fi

    #
    # Basic Checks that SDE is valid
    #
    if [ ! -d $SDE ]; then
        echo "  ERROR: \$SDE ($SDE) is not a directory"
        exit 1
    fi

    cd $SDE
    if [ $? != 0 ]; then
        echo "  ERROR: Cannot change directory to \$SDE"
        exit 1
    fi

    if [ -z $SDE_INSTALL ]; then
        echo "WARNING: SDE_INSTALL Environment variable is not set"
        echo "         Assuming $SDE/install"
        export SDE_INSTALL=$SDE/install
    else
        echo "Using SDE_INSTALL ${SDE_INSTALL}"
    fi
    
    if [[ ":$PATH:" == *":$SDE_INSTALL/bin:"* ]]; then
        echo "Your PATH contains \$SDE_INSTALL/bin. Good"
    else
        echo "Adding $SDE_INSTALL/bin to your PATH"
        PATH=$SDE_INSTALL/bin:$PATH
    fi

    #
    # Check SDE version
    #
    if SDE_MANIFEST=`ls $SDE/*.manifest 2> /dev/null`; then 
        echo Found `basename $SDE_MANIFEST .manifest` in \$SDE
    else
        echo "  ERROR: SDE manifest file not found in \$SDE"
        exit 1
    fi

    SDE_PACKAGE_LIST=`tr -d ' ' < $SDE_MANIFEST`
    
    #
    # Check the current CPU Architecture
    #
    #if [ $build_arch != `uname -m` ]; then
    #    print_help_arch
    #    exit 1;
    #fi

    #
    # Check available RAM
    #
    total_mem=`grep MemTotal /proc/meminfo | sed -e 's/.* \([0-9]*\) .*/\1/'`
    total_mem_gb=$[total_mem/1000000]
    if [ $total_mem_gb -lt $sde_min_gb ]; then
        echo "ERROR: You system has only ${total_mem_gb}GB of RAM"
        echo "       To build SDE you will need at least ${sde_min_gb}GB"
        exit 1
    fi

    #
    # Basic System Info
    #
    ncpus=`get_ncpus`
    echo "This system has ${total_mem_gb}GB of RAM and ${ncpus} CPU(s)"

    #
    # For parallel builds we need to make sure each process gets at least
    # $sde_min_gb GB of memory
    recommended_jobs=$ncpus
    if [ $[total_mem_gb/sde_min_gb] -le $ncpus ]; then
        recommended_jobs=$[total_mem_gb/sde_min_gb]
    fi

    #
    # Limit the number of jobs to 32 (COMPILER-827). That's more than enough
    # anyway
    if [ $recommended_jobs -gt 32 ]; then
        recommended_jobs=32
    fi
    
    # The number of jobs can be specified explicitly. In this case do not
    # override it
    if [ $jobs -eq 0 ]; then 
        jobs=$recommended_jobs
    fi

    echo "Parallelization:  Recommended: -j$recommended_jobs   Actual: -j$jobs"
    
    SDE_PACKAGES=$SDE/$packages
    SDE_PKGSRC=$SDE/$pkgsrc
    SDE_BUILD=$SDE/$build
    SDE_LOGS=$SDE/$logs

    return 0
}

#
# This function determines the actual path to the compiler as well as
# its type: older-style p4c-bmv2/p4c-tofino or newer-style p4c
#
check_compiler() {
    if p4c=`which $with_p4c`; then
        p4c_version=`$p4c --version 2>&1 | sed -e 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*.*(.*)\)/\1/'`
        echo "P4 compiler: $p4c"
        echo -n "P4 compiler version: $p4c_version "
        p4c_major=`echo $p4c_version | cut -d. -f1`
    else
        echo "ERROR: The specified compiler <$with_p4c> is not executable"
        return 1
    fi

    if [ $p4c_major -le 5 ]; then
        echo "(p4-hlir-based)"
        default_p4flags="-g --verbose 2"
        # Other useful but more dangerous/time-consuming flags:
        # --print-pa-constraints --parser-timing-reports --create-graphs
    else
        echo "(p4c-based)"
        default_p4flags="-g"
    fi

    return 0
}

#
# This function eterines the actual path to the p4 graph generation program
# as well as its type: older-style p4-graphs or the newer style p4c-graphs
#
check_graphs() { 
    if p4graphs=`which $with_p4graphs`; then
        echo "P4 graphs: $p4graphs"
        echo -n "P4 graphs version: "
        if $p4graphs --version >& /dev/null; then
            p4graphs_version=`$p4graphs --version 2>&1 | tail -1 | cut -d\  -f2`
            p4graphs_major=6
            echo "$p4graphs_version (p4c-based)"
        else
            p4graphs_major=5
            echo "(p4-hlir-based)"
        fi
    else
        echo "The specified graphing utility $with_p4graphs is not executable"
        return 1
    fi

    return 0
}

package_dir() {
    package_name=$1
    shift

    package_list=(`cd $SDE_PKGSRC; ls -d ${package_name}* 2>/dev/null`)
    num_packages=${#package_list[@]}
    case $num_packages in
        0)
            echo ""
            ;;
        1)
            echo ${package_list[0]}
            ;;
        *)
            prompt="\nWARNING: Multiple versions of $package_name package found in \$SDE/$pkgsrc"
            for p in `seq 0 $[$num_packages-1]`; do
                prompt="${prompt}\n    ${p} -- ${package_list[$p]}"
            done
            prompt="$prompt\nPlease choose one(0..$[$num_packages-1])[0]"
            prompt=`echo -e $prompt`
            read -p "$prompt " p
            if [ -z $p ]; then
                p=0
            fi
            echo ${package_list[$p]}
            ;;
    esac
    return 0
}

show_log() {
    echo "=========================" `basename $1` "========================="
    tail -$log_lines $1
    echo "=========================" `basename $1` "========================="
    echo
    echo ERROR: See $1 for details
    echo
}

build_case() {
    P4_NAME=`basename $P4_PATH .p4`
    P4_PREFIX=$P4_NAME

    P4_BUILD=$SDE_BUILD/p4-build/$P4_NAME
    P4_LOGS=$SDE_LOGS/p4-build/$P4_NAME
    P4_INSTALL=$SDE_INSTALL

    p4_build=`package_dir p4-build`
    if [ -z $p4_build ]; then 
        echo "ERROR: p4-build package not found in $SDE"
        return 1
    fi

    p4_examples=`package_dir p4-examples`
    if [ -z $p4_examples ]; then 
        echo "ERROR: p4-examples package not found in $SDE"
        return 1
    fi

    echo -n "Clearing the previous build in \$SDE/build/p4-build/$P4_NAME ... "
    rm -rf $P4_BUILD
    echo DONE
    
    mkdir -p $P4_BUILD
    mkdir -p $P4_LOGS
    cd $P4_BUILD
    
    echo -n "Configuring $P4_NAME in \$SDE/build/p4-build/$P4_NAME ... "
    if $SDE_PKGSRC/${p4_build}/configure        \
           --prefix=$P4_INSTALL                 \
           --with-p4c=$p4c                      \
           P4_PATH=$P4_REALPATH                 \
           P4_NAME=$P4_NAME                     \
           P4_PREFIX=$P4_PREFIX                 \
           P4JOBS=$jobs                         \
           P4FLAGS="$default_p4flags $p4flags"  \
           "$@" &> $P4_LOGS/configure.log; then
        echo DONE
    else
        echo FAILED
        show_log $P4_LOGS/configure.log
        cd $WORKDIR
        return 1
    fi

    echo -n "   Building $P4_NAME ... "
    if make -j${jobs} &> $P4_LOGS/make.log; then
        echo DONE
    else
        echo FAILED
        show_log $P4_LOGS/make.log
        cd $WORKDIR
        return 1
    fi

    echo -n " Installing $P4_NAME in \$SDE_INSTALL ... "
    if make install &> $P4_LOGS/install.log; then
        echo DONE
    else
        echo FAILED
        show_log $P4_LOGS/install.log
        cd $WORKDIR
        return 1
    fi

    #
    # Installing the conf file
    #
    mkdir -p ${P4_INSTALL}/share/p4/targets
    if [ -f $SDE_PKGSRC/${p4_examples}/tofino_single_device.conf.in ]; then 
	CONF_IN=$SDE_PKGSRC/${p4_examples}/tofino_single_device.conf.in
    elif [ -f $SDE_PKGSRC/${p4_examples}/tofino/tofino_single_device.conf.in ]; then
        CONF_IN=$SDE_PKGSRC/${p4_examples}/tofino/tofino_single_device.conf.in
    else
        echo "ERROR: Cannot find tofino_single_device.conf.in. Check your distribution"
        cd $WORKDIR
        return 1
    fi

    if [ -d ${P4_INSTALL}/share/p4/targets/tofino ]; then
	CONF_OUT_DIR=${P4_INSTALL}/share/p4/targets/tofino
    else
        CONF_OUT_DIR=${P4_INSTALL}/share/p4/targets/
    fi
    sed -e "s/TOFINO_SINGLE_DEVICE/${P4_NAME}/"  \
        $CONF_IN                                 \
        > ${CONF_OUT_DIR}/${P4_NAME}.conf 

    cd $WORKDIR
    return 0
}

build_graphs() {
    P4_NAME=`basename $P4_PATH .p4`
    P4_BUILD=$SDE_BUILD/p4-build/$P4_NAME
    GRAPHS_DIR=$P4_BUILD/tofino/$P4_NAME/graphs

    mkdir -p $GRAPHS_DIR
    echo -n "   Building $P4_NAME graphs in \`graphs_dir $P4_NAME\` ... "
    if [ $p4graphs_major -le 5 ]; then 
        $p4graphs                                                         \
            -D__TARGET_TOFINO__                                           \
            -I$SDE_INSTALL/share/p4_lib                                   \
            --primitives $SDE_INSTALL/share/p4_lib/tofino/primitives.json \
            --gen-dir $GRAPHS_DIR                                         \
            $P4_REALPATH > $GRAPHS_DIR/graphs.log 2> $P4_LOGS/graphs.log
        if [ $? -eq 0 ]; then
            echo DONE
        else
            echo FAILED
            show_log $GRAPHS_DIR/graphs.log
            return 1
        fi
    else
        echo FAILED
        echo "p4c-based graphing utility not supported yet"
        
        #$p4graphs                                                         \
        #    -D__TARGET_TOFINO__                                           \
        #    -I$SDE_INSTALL/share/p4_lib                                   \
        #    --graphs-dir $GRAPHS_DIR                                      \
        #    --p4v $p4version                                              \
        #    $P4_REALPATH > $GRAPHS_DIR/graphs.log 2> $P4_LOGS/graphs.log
        #if [ $? -eq 0 ]; then
        #    echo DONE
        #else
        #    echo FAILED
        #    show_log $GRAPHS_DIR/graphs.log
        #    return 1
        #fi
    fi
    return 0
}

############################################################################
##########################     M A I N    ##################################
############################################################################

WORKDIR=`pwd`

#
# Option Processing
#
opts=`getopt -o hvj:                                             \
             -l help -l version -l jobs:                         \
             -l with-tofino   -l without-tofino   -l no-tofino   \
             -l with-tofinobm -l without-tofinobm -l no-tofinobm \
             -l with-bmv2     -l without-bmv2     -l no-bmv2     \
             -l with-thrift   -l without-thrift   -l no-thrift   \
             -l with-graphs   -l without-graphs   -l no-graphs   \
             -l p4flags:                                         \
             -l with-p4c: -l with-p4graphs: -l p4v:              \
             -- "$@"`

if [ $? != 0 ]; then
  print_help
  exit 1
fi
eval set -- "$opts"
      
while true; do
    case "$1" in
        -h|--help)     print_help;    exit 0;;
        -v|--version)  print_version; exit 0;;
        -j|--jobs)
            jobs=$2;                         shift 2;;
        --with-tofino)
            with_tofino="--with-tofino";    shift 1 ;;
        --without-tofino|--no-tofino)
            with_tofino="";                  shift 1;;
        --with-tofinobm)
            with_tofinobm="--with-tofinobm"; shift 1;;
        --without-tofinobm|--no-tofinobm)
            with_tofinobm="";                shift 1;;
        --with-bmv2)
            with_bmv2="--with-bmv2";         shift 1;;
        --without-bmv2|--no-bmv2)
            with_bmv2="";                    shift 1;;
        --with-thrift)
            with_thrift="--enable_thrift";   shift 1;;
        --without-thrift|--no-thrift)
            with_thrift="";                  shift 1;;
        --with-graphs)
            with_graphs=1;                   shift 1;;
        --without-graphs|--no-graphs)
            with_graphs=0;                   shift 1;;
        --p4flags)
            p4flags=$2;                      shift 2;;
        --with-p4c)
            with_p4c=$2;                     shift 2;;
        --with-p4graphs)
            with_p4graphs=$2;                shift 2;;
        --p4v)
            case $2 in
                [Pp]4[-_]14|14)
                    p4v=p4_14
                    ;;
                [Pp]4[-_]16|16)
                    cat <<EOF
********************************************************************
This version of the script does not support building P4_16 programs. 

P4_16 support in SDE-8.2.0 is Alpha. 

Please, follow the instructions from the official documentation. 

For all questions, please email sde-alpha@barefootnetworks.com
********************************************************************
EOF
                    exit 1
                    ;;
                *) echo "Incorrect P4 version ($2) specified"
                   exit 1
                   ;;
            esac
            shift 2
            ;;
        --) shift; break;
    esac
done

#
# Here we go...
#

P4_PATH=$1
shift

if [ -z $P4_PATH ]; then
    print_help
    exit 1
fi

if [ ! -f $P4_PATH ]; then
    echo "ERROR: P4 program $P4_PATH doesn't exist or is not readable"
    print_help
    exit 1
fi

P4_REALPATH=$(realpath $P4_PATH)

# Do not automatically build graphs for simple_switch-only programs, since
# they require different parameters (and we do not support that in SDE in
# general)
if [ -z $with_tofino ]; then
   if [ -z $with_tofinobm ]; then
      with_graphs=0
   fi
fi

check_environment
check_compiler
check_graphs

build_case $with_tofino $with_tofinobm $with_bmv2 $with_thrift "$@"

if [ $with_graphs -ne 0 ]; then
    if [ ! -z `which dot` ]; then
        build_graphs
    fi
fi
