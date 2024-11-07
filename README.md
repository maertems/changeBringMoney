# changeBringMoney
Changer ca rapporte !

Quick Start

- Complete ccr.conf with your creds and gps location of your home and office. Keep only 6 digit after the dot. 
- Run ./dependencyCheck.sh and install all missing binaries
- Test the software with ./checkTrajets.sh and ./runAction.sh

If all good, let's go !


How it's working ?

First, you need to declare a trip beetwen 07.00 AM and 07.30 AM or 04.30 PM and 05.00 PM. The script will open your trip by sending a request to API.
You need to wait the end off traffic jam time, 09.00 AM or 06.30 PM.
At this time, the script create a list of GPS points for evry minutes since the trip opening. It's about 100-120 points. And data are sent to the API.
That's all !!

In the morning, home GPS position is used and for the evening it's the office position.

I am using some tricks hide we are using some script instead of app.
- At the script's launch, there is a random between 2 to 25 mins to start
- Before doing action, there is an other random sleep (2-10 secs)
- For GPS points, evevry random x mins (5-10) GPS position is changing. The range is arround +/- 10m


/!\ Do not open your app when a trip is beeing opened and not closed.


You can use a dry run to see what append :

./runAction.sh auto

You can test what appening if some actions are forced :
To declare and opening a trip :
./runAction.sh start

To close and send GPS points for an open trip :
./runAction.sh stop

(Noting is sent to API is you don't add 'prod' at the end of command)


To be automatic, use /etc/crontab with this line

0,30    7,9,16,18       * * *   root    /home/changeBringMoney/runAction.sh auto prod >/dev/null 2>/dev/null


For all trip, there is some logs in /home/changeBringMoney/logs/<YYYY-MM-DD>/<MATIN|SOIR>/





