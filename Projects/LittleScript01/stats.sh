#!/bin/bash
grep "OK DOWNLOAD" cdlinux.ftp.log | cut -d '"' -f 2,4 | sort -u | cut -d '"' -f 2 | sed "s#.*/##" >> results
grep " 20. " cdlinux.www.log  | cut -d " " -f 7,1 | cut -d ":" -f 2 | sort -u | cut -d " " -f 2 | sed "s#.*/##" | cut -d "?" -f 1 >> results
cat results | sort | uniq -c | grep "\.iso"
rm results