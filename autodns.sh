#!/bin/bash


echo $'\e[1;3;7;5m'AUTO-DNS$'\e[0m'

FILEHOME="/etc"
FILENAME="db.pn1.ci.lan"
cp $FILEHOME/bind/$FILENAME $FILEHOME/bind/db.backup/$FILENAME-`date +%d-%h-%y-%T`
SERIAL_COUNT=$(cat $FILEHOME/bind/$FILENAME | grep "Serial" | awk '{print $1}' | cut -f1 -d":" | uniq)
BACKUP_FILE=$(find $FILEHOME/bind/db.backup -type f | xargs ls -lt | head -1 | awk '{print $9}')
CONF_FILE=$(find $FILEHOME/bind -type f | xargs ls -lt | head -2 | tail -1 | awk '{print $9}')
RENAME=($FILEHOME/bind/$FILENAME-backup-`date +%T`)
REPLACE=($FILEHOME/bind/$FILENAME)
TIMESTAMP=$(date +%d-%h-%y-%T)
DESTINATION="/var/log/DNS-MAIL"

if [ ! -d "$DESTINATION" ]
then
mkdir -p $DESTINATION
fi

echo

read -p " Enter the server name : " SERVER

read -p " Enter the server IP : " IP

if [ -z "$SERVER" ] || [ -z "$IP" ]; then
echo " Input is blank. Please check..!"
exit
fi

if [[ "$IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
        echo "" > /dev/null
else
        echo "You have entered an invalid IP address!"
        exit
fi

while true; do
read -p " Do you want to 'add/remove' the HOST : " ACTION
echo

case $ACTION in
add ) echo "entered the add action";
break;;
remove ) echo "entered the remove action";
break;;
* ) echo "Invalid action input";;
esac
done

cat $FILEHOME/bind/$FILENAME | grep $SERVER > /dev/null

if [ $? -eq 0 ] && [ "$ACTION" == "add" ]; then
echo "Server '$SERVER' entry already exists."
exit
fi

cat $FILEHOME/bind/$FILENAME | grep $IP > /dev/null

if [ $? -eq 0 ] && [ "$ACTION" == "add" ]; then
echo "IP '$IP' is binded with different host. Please cross-verify the IP before adding."
exit
fi


#CMD=`nslookup $IP | head -2`

#if [ $? -eq 0 ] && [ "$ACTION" == "add" ];
#then
#        echo "This is IP $IP is binded with the below details. Please cross-check before add"
#        echo ""
#        echo "$CMD"
#        echo ""
#        exit
#fi

cat $FILEHOME/bind/$FILENAME | grep $SERVER > /dev/null

if [ $? -ne 0 ] && [ "$ACTION" == "remove" ]; then
echo "Server '$SERVER' entry doesn't exist."
exit
fi

read -p "Comments: " CMNT

while true; do

read -p "Are you sure you want to proceed? (submit/cancel) : " sc

case $sc in
        submit ) echo "Proceeding with the current action.";
                break;;
        cancel ) echo "Exiting from the current action and not made any changes...";
                exit;;
        * ) echo "Invalid response";;
esac

done

#SUM=$(("$SERIAL_COUNT" + 1))
SUM=$(expr $SERIAL_COUNT + 1)

######################  ADDING HOST AND SERIAL COUNT UPDATE ###############################

if [[ "$ACTION" == "add" ]]; then
sed -ie "/^sfo-pn1-cont202./a $SERVER  IN        A       $IP" $FILEHOME/bind/$FILENAME
sed -i s/${SERIAL_COUNT}/${SUM}/g $FILEHOME/bind/$FILENAME
CHK_ZONEFILE=$(sudo named-checkzone pn1.ci.lan /etc/bind/db.pn1.ci.lan | wc -c) > /dev/null
if [ "$CHK_ZONEFILE" -eq 952 ]; then
#sudo /etc/init.d/bind9 restart > /dev/null 2>&1
sudo systemctl restart bind9 > /dev/null 2>&1
NEWSERIAL_COUNT=$(cat $FILEHOME/bind/$FILENAME | grep "Serial" | awk '{print $1}' | cut -f1 -d":" | uniq)
echo "  Old serial count       New serial count" >> $DESTINATION/DNS-$TIMESTAMP.txt
echo " ============================== " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "   $SERIAL_COUNT             $NEWSERIAL_COUNT" >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "'Server $SERVER with IP $IP' entry has been added successfully..." >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "COMMENTS : $CMNT " >> $DESTINATION/DNS-$TIMESTAMP.txt
PROCESS=$(pgrep bind | wc -l)
echo "'Host $SERVER with IP $IP' entry has been added successfully..."
echo "Zone file is $CHK_ZONEFILE FYI... the Zone file value should be equal to 952"
echo "Bind process count is $PROCESS FYI... the Bind process count should be 1."
#mail -s 'DNS Update: From SFO-PN1-DNS201' kbb@gmail.com < "$DESTINATION/DNS-$TIMESTAMP.txt"
mail -s 'DNS Update: From SFO-PN1-DNS01' kbb@gmail.com < "$DESTINATION/DNS-$TIMESTAMP.txt"
else
mv $CONF_FILE $RENAME
mv $BACKUP_FILE $REPLACE
NEWSERIAL_COUNT=$(cat $FILEHOME/bind/$FILENAME | grep "Serial" | awk '{print $1}' | cut -f1 -d":" | uniq)
echo "  Old serial count       New serial count" >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo " ============================== " >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "   $SERIAL_COUNT             $NEWSERIAL_COUNT" >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "Tried adding the host $SERVER entry with IP $IP, something went wrong..! Reverted the changes."
echo "Tried adding the host $SERVER entry with IP $IP, something went wrong..! Reverted the changes." >> $DESTINATION/DNS_error-$TIMESTAMP.txt
#mail -s "DNS WARNING: From SFO-PN1-DNS201: Something went wrong..!" kbb@gmail.com < "$DESTINATION/DNS_error-$TIMESTAMP.txt"
mail -s "DNS WARNING: From SFO-PN1-DNS201: Something went wrong..!" kbb@gmail.com < "$DESTINATION/DNS_error-$TIMESTAMP.txt"
fi
fi

######################  REMOVING HOST AND SERIAL COUNT UPDATE ###############################

if [[ "$ACTION" == "remove" ]]; then
sed -i "/$SERVER/d" $FILEHOME/bind/$FILENAME
sed -i s/${SERIAL_COUNT}/${SUM}/g $FILEHOME/bind/$FILENAME
CHK_ZONEFILE=$(sudo named-checkzone pn1.ci.lan /etc/bind/db.pn1.ci.lan | wc -c) > /dev/null
if [ "$CHK_ZONEFILE" -eq 952 ]; then
#sudo /etc/init.d/bind9 restart > /dev/null 2>&1
sudo systemctl restart bind9 > /dev/null 2>&1
NEWSERIAL_COUNT=$(cat $FILEHOME/bind/$FILENAME | grep "Serial" | awk '{print $1}' | cut -f1 -d":" | uniq)
echo "  Old serial count       New serial count" >> $DESTINATION/DNS-$TIMESTAMP.txt
echo " ============================== " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "   $SERIAL_COUNT             $NEWSERIAL_COUNT" >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "'Server $SERVER with IP $IP' entry has been removed successfully..." >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS-$TIMESTAMP.txt
echo "COMMENTS : $CMNT " >> $DESTINATION/DNS-$TIMESTAMP.txt
PROCESS=$(pgrep bind | wc -l)
echo "'Server $SERVER with IP $IP ' entry has been removed successfully..."
echo "Zone file is $CHK_ZONEFILE FYI... the Zone file value should be equal to 952"
echo "Bind process count is $PROCESS FYI... the Bind process count should be 1."
#mail -s 'DNS Update: From SFO-PN1-DNS201' kbb@gmail.com < "$DESTINATION/DNS-$TIMESTAMP.txt"
mail -s 'DNS Update: From SFO-PN1-DNS201' kbb@gmail.com < "$DESTINATION/DNS-$TIMESTAMP.txt"
else
mv $CONF_FILE $RENAME
mv $BACKUP_FILE $REPLACE
NEWSERIAL_COUNT=$(cat $FILEHOME/bind/$FILENAME | grep "Serial" | awk '{print $1}' | cut -f1 -d":" | uniq)
echo "  Old serial count       New serial count" >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo " ============================== " >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "   $SERIAL_COUNT             $NEWSERIAL_COUNT" >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "                                " >> $DESTINATION/DNS_error-$TIMESTAMP.txt
echo "Tried removing the Server $SERVER entry with IP $IP, something went wrong..! Reverted the changes."
echo "Tried removing the Server $SERVER entry with IP $IP, something went wrong..! Reverted the changes." >> $DESTINATION/DNS_error-$TIMESTAMP.txt
#mail -s "DNS WARNING: From SFO-PN1-DNS201 Something went wrong..!" kbb@gmail.com < "$DESTINATION/DNS_error-$TIMESTAMP.txt"
mail -s "DNS WARNING: From SFO-PN1-DNS201 Something went wrong..!" kbb@gmail.com < "$DESTINATION/DNS_error-$TIMESTAMP.txt"
fi
fi

root@sfo-pn1-dns201:/home/kbb-prd/bind#
