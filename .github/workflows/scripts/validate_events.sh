#!/bin/bash

# match any string that starts with "event" and its name does not start with Log
EVT=`grep -orP '$\s+event\s+(?!Log)(\w+)\s*' contracts/*`

if [ -z "$EVT" ]; then
    echo "All event definitions start with 'Log'"
else
    echo "Found event definitions not starting with 'Log':"
    echo "$EVT"
    exit 1
fi

# check for event defintions with attributes 'policyId', 'applicationId' or 'metadataId'
EVT=`grep -orP '$\s+event\s+\w+\s*\(.*(policyId|applicationId|metadataId).*\)' contracts/*`

if [ -z "$EVT" ]; then
    echo "No event definitions contain attributes 'policyId', 'applicationId' or 'metadataId'"
else
    echo "Found event definitions containing attributes 'policyId', 'applicationId' or 'metadataId':"
    echo "$EVT"
    exit 1
fi
