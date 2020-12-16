#!/bin/dash

# Will print even if no args given like in shell if using sheeple from second last commit

# EDIT 9 Aug 2020:
# I have decided to turn this OFF because it can cause errors during numerical comparisons.
# Since in my previous sheeple I've set $ARGV[0] = $_default0 or "", this WILL cause warning system to go off
# when I tested my demo00.sh and enter 0 for input. (And we have to leave -w on in perl code)
# Because this behaviour is less likely to be encountered given we do A LOT of comparisons in
# everyday programming...I'm going to have to leave it. There's no easy fix and I can't have everything ):

echo -n "This is first arg [$1], this is second arg: [$2]"; echo -n "blahblahblah"

