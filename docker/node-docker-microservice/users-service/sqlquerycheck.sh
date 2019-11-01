#!/bin/bash

mysql -uusers_service -p123 <<MY_QUERY
USE users
SHOW tables
SELECT * FROM directory;
MY_QUERY

echo "MySQL Query is "

if [ "" == "" ]; then
    echo "Critical state"
    exit 2
else
    exit 0
fi