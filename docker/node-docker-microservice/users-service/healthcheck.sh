#!/bin/sh

free
memusage=6

echo
echo "Memory usage is roughly %"

if [ "" -gt "98" ]; then
    echo "Critical state"
    exit 2
elif [ "" -gt "80" ]; then
    echo "Warning state"
    exit 1
else
    exit 0
fi