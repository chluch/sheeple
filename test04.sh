#!/bin/dash

a=1
b=2

if [ $(expr $a + $b) = 3 ]
then
    echo 'a + b = 3'
else
    echo 'sum of "a" and "b" is not 3'
fi

