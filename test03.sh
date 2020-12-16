#!/bin/dash

a=1
b=2

product=$(expr $a \* $b)
echo $product

sum=`expr $a + $b`
echo $sum

difference=$(($b - $a))
echo $difference
