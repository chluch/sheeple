#!/bin/dash

if [ "$1" = "a" ] && [ "$2" = "b" ] && [ "$3" = "c" ] && [ "$4" = "d" ]; then
    echo $1: Azure Kingfisher; echo "$2: Bin Chicken"; echo $3: Cassowary; echo "$4: Dollarbird"
else
    echo "$0: Need to enter a b c d in command-line."
    exit 0;
fi
