#!/bin/dash

if [ "$#" -ne 2 ]; then
    echo "$0: usage: <integer> <integer>"
    exit 1
fi

a=$1
b=$2

if [ `expr $a \* $b` -gt 120 ]; then echo 'greater than 120'; elif [ `expr $a \* $b` -eq 120 ]; then echo 'equal to 120'; else echo 'less than 120'; fi

