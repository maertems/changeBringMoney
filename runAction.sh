#!/bin/bash

action=$1
go=$2


userAgent="IOS_18.1_1.2.0"
myHome="/home/changeBringMoney"

##--- Custom personal data
personalData=`cat $myHome/ccr.conf`
login=`echo "$personalData" | grep "login=" | cut -d \= -f 2`
pass=`echo "$personalData" | grep "pass=" | cut -d \= -f 2`
fileToken=`echo "$personalData" | grep "fileToken=" | cut -d \= -f 2`
fileCookie=`echo "$personalData" | grep "fileCookie=" | cut -d \= -f 2`
lat_office=`echo "$personalData" | grep "lat_office=" | cut -d \= -f 2`
long_office=`echo "$personalData" | grep "long_office=" | cut -d \= -f 2`
lat_home=`echo "$personalData" | grep "lat_home=" | cut -d \= -f 2`
long_home=`echo "$personalData" | grep "long_home=" | cut -d \= -f 2`
range_lat=`echo "$personalData" | grep "range_lat=" | cut -d \= -f 2`
range_long=`echo "$personalData" | grep "range_long=" | cut -d \= -f 2`

##-- / END of data

#-- Check we are running only once
#isRunning=`ps auwx | grep runAction | grep -v grep | wc -l`
#if [ $isRunning -gt 1 ]
#then
#	echo "Script already running... exit"
#	exit;
#fi


echo "Start script"


#-- check actual time
myDateNow=`date -u +%s`

myDay=`date -u +"%F"`
midDay=`date -u -d "${myDay} 12:00:00" +%s`
trip=""
endDate=""
isOpenDay="no"

#-- check if we are in an open days. weeks without off days and week end
if [ -f ${myHome}/openDays ]
then
	for week in `cat ${myHome}/openDays | sed -e "s/},{/\n/g" | sed -e "s/\[{//" | sed -e "s/}\]//" | cut -d \" -f 4,8`
	do

        	begin=`echo $week | cut -d \" -f 1`
        	end=`echo $week | cut -d \" -f 2`

        	#echo "Week from $begin to $end"

        	if [ "$myDay" \> "$begin" ] && [ "$myDay" \< "$end" ] || [ "$myDay" == "$begin" ] ||  [ "$myDay" == "$end" ]
        	then
                	#echo "   -> found $day"
			isOpenDay="yes"
        	fi
	done

	if [ "$isOpenDay" == "no" ] && [ "$go" == "prod" ]
	then
		echo "Not an open day. exit "
		exit
	fi
fi



if [ "$go" == "prod" ]
then
	waitDelay=`shuf -i 75-1200 -n 1`
	echo "Waiting $waitDelay before doing somthing...."
	sleep $waitDelay
else
	echo " no delay ------------------------ Dry run ----------"
fi



if [ $myDateNow -le $midDay ]
then
	trip="MATIN"
        endDate="${myDay}T08:00:00.000Z"
        endDateTime=`date -u +"%s" --date="${myDay} 08:00:00"`
	endDateSendingData=`date -u +"%s" --date="${myDay} 09:00:00"`
	registrationDateStart=`date -u +"%s" --date="${myDay} 06:00:00"`
	registrationDateEnd=`date -u +"%s" --date="${myDay} 06:30:00"`
        latOrig=$lat_home
        longOrig=$long_home
else
        trip="SOIR"
        endDate="${myDay}T17:30:00.000Z"
        endDateTime=`date -u +"%s" --date="${myDay} 17:30:00"`
	endDateSendingData=`date -u +"%s" --date="${myDay} 19:30:00"`
	registrationDateStart=`date -u +"%s" --date="${myDay} 15:30:00"`
	registrationDateEnd=`date -u +"%s" --date="${myDay} 16:00:00"`
        latOrig=$lat_office
        longOrig=$long_office
fi


if [ "$action" == "auto" ] || [ "$action" == "start" ] || [ "$action" == "stop" ]
then
		if [ $myDateNow -ge $registrationDateStart ] && [ $myDateNow -le $registrationDateEnd ]
		then
			echo "We are in a start/declaration period"
			if [ `find ${myHome}/current.dateBegin -mmin -60` ]
                        then
				echo "We already declare a trip"
				go="noprod"

				if [ "$action" == "auto" ]
				then
					action="status"
				else
					action="start"
				fi
			else
				if [ "$action" == "auto" ]
                                then
                                	action="start"
                                fi
			fi
		else
	
			if [ $myDateNow -ge $endDateTime ] && [ $myDateNow -le $endDateSendingData ]
			then
				echo "We are in a stop/sendingData period"
				if [ ! -f ${myHome}/current.dateBegin ] 
				then
					echo "We already send data."
					go="noprod"

					if [ "$action" == "auto" ]
                                	then
                                        	action="status"
                                	else
                                        	action="stop"
                                	fi
				else
					if [ "$action" == "auto" ]
					then
						action="stop"
					fi
				fi
			else
				echo "We do not have things to do.."
				go="noprod"
                                if [ "$action" == "auto" ]
				then
					action="status"
				fi
			fi
		fi
else
	echo "usage: $0 auto|start|stop [prod]"
	exit
fi



echo "action: $action"
echo "trip: $trip"
echo "openDay: $isOpenDay"





result=""
if [ ! -f "$fileToken" ]
then
	echo "No token file. Login IN"
	result=`curl -X POST -d "client_id=ecobonus-front-participant-ios&username=${login}&password=${pass}&grant_type=password&scope=offline_access" -A ${userAgent} \
		https://xn--changerarapporte-ipb.fr/keycloak/realms/ecobonus/protocol/openid-connect/token`

	echo "$result" > $fileToken
else
	echo "Token file exist. Use it"
	result=`cat $fileToken`

	if [ `find $fileToken -mmin +1` ]
	then
		echo "  -> need to refresh token"
		refreshToken=`echo "${result}" | jq ".refresh_token" | sed -e "s/\"//g"  `
		result=`curl -X POST -d "client_id=ecobonus-front-participant-ios&grant_type=refresh_token&refresh_token=${refreshToken}" -A ${userAgent} \
			https://xn--changerarapporte-ipb.fr/keycloak/realms/ecobonus/protocol/openid-connect/token 2>/dev/null `
		echo "$result" > $fileToken
	fi
fi

token=`echo "${result}" | jq ".access_token" | sed -e "s/\"//g" `


html=`curl -A ${userAgent} -c $fileCookie \
	'https://xn--changerarapporte-ipb.fr/keycloak/realms/ecobonus/protocol/openid-connect/auth?response_type=code&client_id=transway-front-ireby&scope=offline_access' 2>/dev/null`
url=""
for line in `echo "${html}" | grep kc-form-login`
do 
	exist=`echo $line | grep action`
	if [ $exist ]
	then
		url=`echo $line | cut -d \" -f 2 | sed -e "s/amp;//g" ` 
	fi
done

data="username=${login}&password=${pass}%21&credentialId=&scope=offline_access"
curl -X POST -d ${data} -A ${userAgent} -b $fileCookie \
	"${url}" >/dev/null 2>/dev/null


##-- to emulate app
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} https://xn--changerarapporte-ipb.fr/back-inscription-programme/mon-compte >/dev/null 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} https://xn--changerarapporte-ipb.fr/back-declaration-effacement/jours-autorises >${myHome}/openDays 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=9" >/dev/null 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=10" >/dev/null 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=11" >/dev/null 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?statut=EN_ATTENTE_DE_JUSTIFICATION" >/dev/null 2>/dev/null
curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?statut=EN_ATTENTE_DE_JUSTIFICATION" >/dev/null 2>/dev/null
# curl -H "Authorization: Bearer ${token}"  -A ${userAgent} 

if [ "$go" == "prod" ]
then
	#-- random sec to simulate navigation in app
	waitDelay=`shuf -i 2-10 -n 1`
	echo "wait $waitDelay"
	sleep $waitDelay
fi


if [ "$action" == "start" ]
then
	echo "start a new trip"

	#-- get authorized days
	# https://xn--changerarapporte-ipb.fr/back-declaration-effacement/jours-autorises

	##-- declaration
	myDateBegin=`date -u +"%s"`
	myDate=`date -u +"%FT%T" --date="@${myDateBegin}"`
	millisA=`shuf -i 0-9 -n 1`
	millisB=`shuf -i 0-9 -n 1`
	millisC=`shuf -i 0-9 -n 1`
	myDate="${myDate}.${millisA}${millisB}${millisC}Z"
	data="{ \"declarationDebutDateTime\": \"${myDate}\", \"debutDateTime\": \"${myDate}\", \"primaryEffacementType\": \"DESHORAGE\" }"

	# data="{ \"declarationDebutDateTime\": \"2024-11-05T15:47:37.634Z\", \"debutDateTime\": \"2024-11-05T15:47:37.634Z\", \"primaryEffacementType\": \"DESHORAGE\" }"

	if [ "$go" == "prod" ]
	then
		#-- create log directory
		mkdir -p ${myHome}/logs/${myDay}/${trip}

		echo "$data" > ${myHome}/logs/${myDay}/${trip}/declarationData

		result=`curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${token}"  -A ${userAgent} -d "${data}" https://xn--changerarapporte-ipb.fr/back-declaration-effacement/effacements 2>/dev/null | jq ".id" | sed -e "s/\"//g" `
		echo $result > ${myHome}/logs/${myDay}/${trip}/id
		echo "${myDateBegin}" > ${myHome}/logs/${myDay}/${trip}/dateBegin
		echo "${myDateBegin}" > ${myHome}/current.dateBegin
	else
		echo "-- dryRun declaration"
		echo "data: $data"
		echo "dateBegin: ${myDateBegin}"
	fi

fi



if [ "$action" == "stop" ]
then
        echo "stop truc"

        if [ "$go" == "prod" ]
        then
		myDateBegin=`cat ${myHome}/current.dateBegin`
	else
		myDateBegin=$registrationDateEnd
	fi


	#-- create data

	#header
	timeRandom=`shuf -i 60-900 -n 1`  # Random from 1min to 15mins to change gps position
	timeTochange=`expr $myDateBegin + $timeRandom`

	#-- define original position
	rangeLatTemp=`echo "$range_lat*100000000000000*2" | bc -l | cut -d \. -f 1`
	rangeLongTemp=`echo "$range_long*10000000000000000*2" | bc -l | cut -d \. -f 1`
	gpsRandomLat=`shuf -i 0-${rangeLatTemp} -n 1`
	gpsRandomLong=`shuf -i 0-${rangeLongTemp} -n 1`
	gpsRandomLat=`echo "$gpsRandomLat/100000000000000" | bc -l`
	gpsRandomLong=`echo "$gpsRandomLong/10000000000000000" | bc -l`

	latInit=`echo "$latOrig-$range_lat" | bc -l`
	longInit=`echo "$longOrig-$range_long" | bc -l`

	lat=`echo "$latInit + $gpsRandomLat" | bc -l | sed -e "s/000000$//"`
	long=`echo "$longInit + $gpsRandomLong" | bc -l | sed -e "s/0000$//"`


	data="{\"finDateTime\": \"${endDate}\",\"suiviHoraires\": ["

	gpsDateTime=`expr $myDateBegin - 8`
	gpsDate=`date -u +"%FT%T" --date="@${gpsDateTime}"`
	gpsDate="${gpsDate}.000Z"
	data="${data} {\"dateTime\": \"${gpsDate}\",\"positionGps\":{\"latitude\": ${lat},\"longitude\": ${long}}}"

	gpsDateTime=$myDateBegin

	while [ $endDateTime -gt $gpsDateTime ]
	do

		if [ $timeTochange -lt $gpsDateTime ]
		then
			#need to change GPS values
			rangeLatTemp=`echo "$range_lat*100000000000000*2" | bc -l | cut -d \. -f 1`
		        rangeLongTemp=`echo "$range_long*10000000000000000*2" | bc -l | cut -d \. -f 1`
        		gpsRandomLat=`shuf -i 0-${rangeLatTemp} -n 1`
        		gpsRandomLong=`shuf -i 0-${rangeLongTemp} -n 1`
        		gpsRandomLat=`echo "$gpsRandomLat/100000000000000" | bc -l`
        		gpsRandomLong=`echo "$gpsRandomLong/10000000000000000" | bc -l`

        		lat=`echo "$latInit + $gpsRandomLat" | bc -l | sed -e "s/000000$//"`
        		long=`echo "$longInit + $gpsRandomLong" | bc -l | sed -e "s/0000$//"`
			
			timeRandom=`shuf -i 60-900 -n 1`  # Random from 1min to 15mins to change gps position
			timeTochange=`expr $gpsDateTime + $timeRandom` 
		fi

		gpsDate=`date -u +"%FT%T" --date="@${gpsDateTime}"`
		gpsDate="${gpsDate}.000Z"
		data="${data},{\"dateTime\": \"${gpsDate}\",\"positionGps\":{\"latitude\": ${lat},\"longitude\": ${long}}}"

		gpsDateTime=`expr $gpsDateTime + 60`
	done

	data="${data}]}"

	if [ "$go" == "prod" ]
	then
		#-- get ID
		if [ ! -f "${myHome}/logs/${myDay}/${trip}/id" ]
		then
			echo "No ID to close... error...."
			exit;
		fi
		id=`cat ${myHome}/logs/${myDay}/${trip}/id`
		echo "id: $id"


		echo "$data" > ${myHome}/logs/${myDay}/${trip}/endDataSent


		httpCode=`curl -sw "%{http_code}" -X PATCH -H "Content-Type: application/json" -H "Authorization: Bearer ${token}"  -A ${userAgent} -d "${data}" \
				"https://xn--changerarapporte-ipb.fr/back-declaration-effacement/effacements/${id}" -o /dev/null`

		echo "$data" > ${myHome}/logs/${myDay}/${trip}/httpCodeForSendingData

		if [ "$httpCode" == "200" ]
		then
			echo "Sending OK !! Good"

			#-- remove current trip
			rm -f ${myHome}/current.dateBegin
		else
			echo "Error when pushing data"
		fi
	else
		echo "$data"
	fi
fi


if [ "$action" == "status" ]
then
	#-- nothing specific checking current trip
	if [ -f "${myHome}/current.dateBegin" ]
	then
		myDateBegin=`cat ${myHome}/current.dateBegin`
		myDay=`date -u +"%F" --date="@${myDateBegin}"`
	        midDay=`date -u -d "${myDay} 12:00:00" +%s`
	        trip=""
	        endDate=""

	        if [ $myDateBegin -le $midDay ]
	        then
	                trip="MATIN"
		else
			trip="SOIR"
		fi


		if [ ! -f "${myHome}/logs/${myDay}/${trip}/id" ]
		then
			echo "No ID found ... error...."
			echo "  file: ${myHome}/logs/${myDay}/${trip}/id"
	        	exit;
		fi
	        id=`cat ${myHome}/logs/${myDay}/${trip}/id`
	        echo "id: $id"

		curl -H "Content-Type: application/json" -H "Authorization: Bearer ${token}"  -A ${userAgent} \
			https://xn--changerarapporte-ipb.fr/back-declaration-effacement/effacements/${id} 2>/dev/null | jq "."

	else
		echo "No current trip. nothing to print"
	fi
fi


