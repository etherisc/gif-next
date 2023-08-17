#!/bin/bash

DUPES=`egrep -or "(ERROR\:[A-Z0-9_-]+)" contracts/* | sort | uniq -cd`

if [ -z "$DUPES" ]; then
    echo "No duplicate error codes found"
else
    echo "Duplicate error codes found:"
    echo "$DUPES"
    exit 1
fi

