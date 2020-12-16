#!/bin/dash

if [ "$#" -ne 1 ]; then
    echo "$0: usage <arg>"
    exit 1
fi

echo this is your arg: $1
echo 'this is your arg: $1'
echo "this is your arg: $1"
echo '""'
echo "'''"
echo "t'h'i's i\"s' y'o\"ur arg \"$1"
echo "this is your \"arg\": $1"
echo 'this is your arg:' "$1"
echo this 'is' "your" 'arg:' $1
echo 'TESTING ECHOS'
echo echo 'echo' "echo"
