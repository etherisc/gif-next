#!/bin/bash

printf "|Errorcode|File|\n|:--|:--|\n"
egrep -or "(ERROR\:[A-Z0-9_-]+\:[A-Z0-9_-]+)" contracts/* | sed -E "s/([^\:]+)\:(.+)/|\2|\1|/g" | sort 
