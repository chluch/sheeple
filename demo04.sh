#!/bin/dash

if [ $# -ne 2 ]; then echo "$0: Usage: <integer> <integer>"; exit 1; fi

arg1=$1
arg2=$2

[ -n "$arg1" ] && [ "$arg1" -eq "$arg1" ] 2>/dev/null
[ -n "$arg2" ] && [ "$arg2" -eq "$arg2" ] 2>/dev/null
if [ $? -eq 0 ]; then
    test $arg1 -lt 10 && test $arg1 -gt 0 && echo arg1: $arg1 is between 0 and 10 || echo arg1: $arg1 is not between 0 and 10
fi

sum=$(expr "$arg1" + "$arg2")
if [ $sum -lt 0 ]; then
    echo Cannot run remaining code if arg1 + arg2 yields a negative number
else
    echo This is sum: $sum, testing while loop with this number...
    n=0
    while [ $n -le $sum ]; do
        echo "Fix 1 bug, get $n more ))))):"
        n=$(( n+1 ))
    done
fi
