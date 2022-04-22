#!/bin/bash

#
# This program simulates the insertion of N random range-matching
# entries in the table and allows one to estimate how many TCAM entries
# will be required
#

#
# Set up the defaults
#
iterations=1000
width=16
max_range=0
algo='./bf_range'
verbose=0

function parse_options() {
    opts=`getopt -o hi:w:r:a:v     \
                 -l help           \
                 -l iterations:    \
                 -l width:         \
                 -l range:         \
                 -l algorithm:     \
                 -l verbose        \
                 -- "$@"`

    if [ $? != 0 ]; then
        print_help
        exit 1
    fi
    
    eval set -- "$opts"
    while true; do
        case "$1" in
            -h|--help) print_help; exit 0           ;;
            -i|--iterations) iterations=$2; shift 2 ;;
            -w|--width) width=$2;           shift 2 ;;
            -r|--range) max_range=$2;       shift 2 ;;
            -a|--algorithm) algo=$2;        shift 2 ;;
            -v|--verbose) verbose=1;        shift 1 ;;
            --) shift; break
        esac
    done

    #
    # Let's do a separate check for algo, since we rely on external
    # programs. 
    if [ ! -x $algo ]; then
        cat <<EOF
ERROR: $algo is not an executable.

       Typically you need to build the bf_range and tcam_range programs by
       running command 

             make -C ~/tools

EOF
        exit 1
    fi

}



function print_help() {
    prog=$0
    cat <<EOF

Usage:
    $prog [-i iterations] [-w bit_width] [-r range_len] [-a algorithm] [-v]

    -i iterations
       Specify the number of entries for the simulation. Default is 1000

    -w bitwidth
       Specify the number of bits in the key (up to 32). Default is 16

    -r range_len
       Specify the maximum size of the range. Actual ranges will have the
       a length between 0 and range_len inclusively. 0 -- no caps on the 
       range length (totally random). Default is 0

    -a algorithm
       Specify the program that will perform the calculation (typically 
       it is ./bf_range or ./tcam_range). Default is ./bf_range

    -v 
       Verbose mode: print the results for each entry

EOF
}

#
# This function allows us to generate a random number without $RANDOM
# because it only provides the numbers in the range beween 0 and 32767
function get_random() {
    echo `od -A n -t u -N 4 /dev/urandom`
}


function run_test() {
    total=0
    total_range_len=0

    max_val=$(( (1 << $width) - 1 ))
    
    for n in `seq 0 $iterations`; do
        # Start of the range is always random
        start=$(( `get_random` % $max_val ))
        
        # Handle the case, where this is the max value
        if [ $start -eq $max_val ]; then
            # The range will then always be [max:max]
            end=$start
        else
            # If max_range has not been specified
            if [ $max_range -eq 0 ]; then
                # Then we'll randomly select the width
                max_end_val=$max_val
            else
                # Otherwise, we'll be selecting randomly withing
                # specified range (and do it safely)
                max_end_val=$(( $start + $max_range ))
                if [ $max_end_val -gt $max_val ]; then
                    max_end_val=$max_val
                fi
            fi
            # The range boundaries are determined, so we can
            # now randomly select where the end will be
            end=$(($start + `get_random` % ($max_end_val - $start)))
        fi
        
        range_len=$(( $end - $start + 1 ))
        total_range_len=$(($total_range_len + $range_len))
        
        # Compute the number of entries
        entries=`$algo $start $end | wc -l`
        total=$(($total + $entries))

        if [ $verbose -gt 0 ]; then
            echo -e "${n}\t${start}\t${end}\t${range_len}\t${entries}"
        fi
    done

    avg_range_len=`echo "scale=2;${total_range_len}/${iterations}" | bc`
    avg_entries=`echo "scale=2;${total}/${iterations}" | bc`
    
    echo "Algorithm:     $algo"
    echo "Bitwidth:      $width"
    echo "Iterations:    $iterations"
    echo "Avg. Range:    $avg_range_len"
    echo "Avg. Entries:  $avg_entries"
}

parse_options $@

run_test
