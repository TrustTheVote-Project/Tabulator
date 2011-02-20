#!/bin/bash
echo -e "** Validation Errors **"
grep -e "err("  lib/validator.rb | sed "s/^\s*//"

echo -e "\n** Validation Warnings **"
grep -e "warn(" lib/validator.rb | sed "s/^\s*//"

echo -e "\n** Operator Command Errors **"
grep -e "opx_err.*\"Command" operator.rb | sed "s/^\s*//"

echo -e "\n** Operator File Errors **"
grep -e "opx_err.*\"File" operator.rb | sed "s/^\s*//"

echo -e "\n** Operator Fatal Errors **"
grep -e "opx_err.*\"Fatal" operator.rb | sed "s/^\s*//"

echo -e "\nThe latter number must be 4 greater than the former ... wait for it"
echo -n -e "\nvalidate.rb errors/warnings:    "
grep -e "err(" -e "warn(" lib/validator.rb | wc -l
echo -n "test tabulator errors/warnings: "
./TEST.sh val | grep -e "\*\*\ [EW]" | wc -l
echo " "