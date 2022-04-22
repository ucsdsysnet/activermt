#!/bin/bash

verbose=0

#set -x

#
# This is a simple heuristical utility that tries to determine if a given
# program is written in P4_16 or P4_14. It works on any file, but the more
# information there is, the more accurate the result is.
#    * If you feed it the fully preprocessed program, the correct result is
#      pretty much guaranteed
#    * If you feed it the top-level file only, the result might be less
#      certain (which is why I strongly suggest to start all your P4 code
#      with the Emacs modeline /* -*- P4_1[46] -*- */
#    * There are some .p4 files that contain nothing but #defines. For these
#      (or if you feed programs in other languages), the program might
#      output "no-p4"
#    * This is not an AI program in bash! Thus it might classify C++ or
#      Java code as p4_16, for example. 
#
function print_help() {
    prog=$0
    cat <<EOF

Usage:
    $prog [-h] [-v level]

    -v level
       Specifies verbosity level:
         0 -- just output the language (default)
         1 -- output total scores
         2 -- output scores for individual elements
EOF
}
    
#
# The function counts how many times a certain pattern has been
# found in a file
#
function score_pattern() {
    file="$1";    shift
    pattern="$1"; shift
    weight="$1" ; shift
    comment="$1"; shift
    
    count=`egrep "$pattern" "$file" | wc -l`
    score=$(($count * $weight))
    if [ $verbose -ge 2 ]; then
        printf "%40s: %3d = %d * %d\n" "$comment" $score $count $weight >& 2
    fi

    echo $score
}

#
# The inline STDIN in this function contains the typical strings that we are
# looking for in a P4_14 program. The function after this one contains the
# definitions for typical P4_16 elements instead
#
# You can add more definitions if you like
#
# Each definition consists of 4 lines:
# --------------
# 1. #include with Angle Brackets
# 2. #include.*<.*>
# 3. -1
# 4.
# -------------
#
# Line 1 contains the explanation what we are looking for (useful for debug)
# Line 2 contains an egrep pattern. Note: for a backslash, you need to use \\\\
# Line 3 contains the weight (importance) of a certain construct. Note how one
#        line uses the weight -1 to discount a certain pattern not relevant for
#        the detection
# Line 4 is empty or it must contain the word END
#
function p4_14_score()
{
    score=0

    while true; do
        read comment
        read pattern
        read weight
        read end

        score=$(( $score + `score_pattern $1 "$pattern" "$weight" "$comment"` ))
        if [ x$end == 'xEND' ]; then
            break;
        fi
    done <<EOF
P4_14 Emacs Mode Line
/\\\\* -\\\\*-\ P4_14\ -\\\\*-\ \\\\*/
10

apply() statement invocations
[^._[:alnum:]][[:space:]]*apply[[:space:]]*\\\\(
1

extract() statement invocations
[^._[:alnum:]][[:space:]]*extract *\\\\(
1

return statements in the parser
return[[:space:]]+(select[[:space:]]*\\\\(|ingress*[[:space:]]*;)
2

header and metadata instantiators
(header|metadata)[[:space:]]+[[:alpha:]_][[:alnum:]_]*[[:space:]]+[[:alpha:]_][[:alnum:]_]*(\\\\[[[:digit:]]\\\\])?[[:space:]]*;
2

header_type type declarations
header_type +[[:alpha:]_][[:alnum:]_]*[[:space:]]*{
2

modify_field() primitive invocations
modify_field[[:space:]]*\\\\(
1

table attributes with a brace
(reads|actions)[[:space:]]*{
1

table attributes with a colon
(size,default_action|type)[[:space:]]*:
1

P4_14 standard objects
(counter|meter|register|field_list|field_list_calculation|blackbox_type)[[:space:]]+[[:alpha:]_][[:alnum:]_]*[[:space:]]*{
2

controls and parsers without parameters
(control|parser)[[:space:]]*[[:alpha:]_][[:alnum:]_]*[[:space:]]*[^(]
2
END

EOF
    echo $score
}

function p4_16_score()
{
    score=0

    while true; do
        read comment
        read pattern
        read weight
        read end

        score=$(( $score + `score_pattern $1 "$pattern" "$weight" "$comment"` ))
        if [ x$end == 'xEND' ]; then
            break;
        fi
    done <<EOF
P4_16 Emacs Mode Line
/\\\\* -\\\\*-\ P4_16\ -\\\\*-\ \\\\*/
10

Angle Brackets 
<.*>
1

#include with Angle Brackets
#include.*<.*>
-1

Apply method invocations
\\\\.[[:space:]]*apply *\\\\(
1

Apply method definitions
[dht>][[:space:]]+apply *\\\\(
1

Apply blocks
apply[[:space:]]*{
5

extract() method invocations
\\\\.[[:space:]]*extract[[:space:]]*\\\\(
1

emit() method invocations
\\\\.[[:space:]]*emit[[:space:]]*\\\\(
2

transition statements
transition[[:space:]]+(select[[:space:]]*\\\\(|[[:alpha:]_][[:alnum:]_]*[[:space:]]*;)
1

parser/control with parameters
(control|parser)[[:space:]]*[[:alpha:]_][[:alnum:]_]*[[:space:]]*\\\\(
2

header statements as type declarations
(header|struct|header_union)[[:space:]]+[[:alpha:]_][[:alnum:]_]*[[:space:]]*{
1

P4_16 table properties with a brace
[[:space:]]*(keys|actions|size|default_action)[[:space:]]*=
1

P4_16 saturated operations
\\\\|[+-]\\\\|
10

P4_16 bit-slicing operations
\\\\[[[:space:]]*[[:digit:]]+[[:space:]]*:[[:space:]]*[[:digit:]]+[[:space:]]*\\\\]
1

P4_16 binary const with explicit width
[[:digit:]]+[sw]0b[01]+
2

P4_16 decimal const with explicit width
[[:digit:]]+[sw][[:digit:]]+
2

P4_16 hex const with explicit width
[[:digit:]]+[sw]0x[[:xdigit:]]+
2

"main" package instantiation
[[:space:]]*main[[:space:]]*;
5
END

EOF
    echo $score
}

function main() {
    if [ $verbose -ge 2 ]; then
        echo "Calculating P4_14 score" >& 2
    fi
    
    p4_14_score=`p4_14_score $1`
    
    if [ $verbose -ge 1 ]; then
        echo "P4_14:" $p4_14_score >&2
    fi

    if [ $verbose -ge 2 ]; then
        echo "Calculating P4_16 score" >& 2
    fi
    
    p4_16_score=`p4_16_score $1`
    
    if [ $verbose -ge 1 ]; then
        echo "P4_16:" $p4_16_score >&2
    fi

    if [ $p4_14_score -eq 0 -a $p4_16_score -eq 0 ]; then
        echo "no-p4"
    else
        if [ $p4_14_score -gt $p4_16_score ]; then
            echo "p4-14"
        else
            echo "p4_16"
        fi
    fi
}

#
# Parse Options
#
opts=`getopt -o hv:         \
             -l help        \
             -l verbose:    \
             -- "$@"`

if [ $? != 0 ]; then
    print_help
    exit 1
fi

eval set -- "$opts"
while true; do
    case "$1" in
        -h|--help) print_help;    exit 0  ;;
        -v|--verbose) verbose=$2; shift 2 ;;
        --) shift; break
    esac
done

main $1
