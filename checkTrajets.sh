#!/bin/bash

id=$1

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


echo "Start script"

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


if [ "$id" != "" ]
then
	curl -H "Content-Type: application/json" -H "Authorization: Bearer ${token}"  -A ${userAgent} \
		https://xn--changerarapporte-ipb.fr/back-declaration-effacement/effacements/${id} 2>/dev/null | jq "."
else

	##-- to emulate app
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} https://xn--changerarapporte-ipb.fr/back-inscription-programme/mon-compte 2>/dev/null | jq "."
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} https://xn--changerarapporte-ipb.fr/back-declaration-effacement/jours-autorises >/dev/null 2>/dev/null
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=9"  2>/dev/null | jq "."
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=10" 2>/dev/null | jq "."
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?year=2024&month=11" 2>/dev/null | jq "."
	curl -H "Authorization: Bearer ${token}"  -A ${userAgent} "https://xn--changerarapporte-ipb.fr/back-restitution-informations/mes-infos/effacements?statut=EN_ATTENTE_DE_JUSTIFICATION" 2>/dev/null | jq "."
	# curl -H "Authorization: Bearer ${token}"  -A ${userAgent} 
fi

exit
