#!/bin/sh
# Diagnostics limit test (lua/genja/ext/diag-limit.lua): 7 ShellCheck SC2086
# (unquoted variable) via bashls, one per line. Expected: 3 drawn, ]d visits all 7.
echo $1
echo $2
echo $3
echo $4
echo $5
echo $6
echo $7
