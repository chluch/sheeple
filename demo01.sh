#!/bin/dash
# Demonstrating behaviours of quoted and unquoted $* and $@
# However this does NOT work if input has trailing whitespace like
# 1 2 "hello world    " 3

echo '$*:'
for i in $*
do
    echo $i
done

echo '"$*":'
for j in "$*"
do
    echo $j
done

echo '$@:'
for m in $@
do 
    echo $m
done

echo '"$@":'
for n in "$@"
do
    echo $n
done
