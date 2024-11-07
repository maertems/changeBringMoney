#!/bin/bash

#-- test bin we use

for i in bc shuf curl date find
do
	#-- check soft
	`$i --version >/dev/null 2>/dev/null`
	if [ "$?" == "0" ]
	then
		found="ok"
	else
		found="NOT FOUND"
	fi

	echo "$i: $found"

done

