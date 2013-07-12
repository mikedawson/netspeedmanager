#!/bin/bash


#
# Args are : admin password, username, new user password
#
ADMINPASS=$1
USERNAME=$2
USERPASS=$3

#base args
SERVERNNAME=localhost
LOGGED_IN=n
CURRENTATTEMPT=0
MAXATTEMPTS=5

WORKDIR=/tmp/userpass-$(date '+%s')

mkdir $WORKDIR

STARTDIR=$(pwd)

cd $WORKDIR

while [ "$LOGGED_IN" = "n" ]; do
        echo "Logging in"
       	curl -s -k -b .sme_cookies -c .sme_cookies -F username=admin \
        -F "password=$ADMINPASS" \
       	https://$SERVERNNAME/server-common/cgi-bin/login > \
        loginresult.tmp

        RESULTOK=$(grep -i successful loginresult.tmp)
        if [ ! "foo$RESULTOK" == "foo" ]; then
               	echo "Detected successful login"
                LOGGED_IN="y"
        else
                CURRENTATTEMPT=$(( $CURRENTATTEMPT + 1 ))
                if [ $CURRENTATTEMPT -gt $MAXATTEMPTS ]; then
                        echo "Retry limit $MAXATTEMPTS exceeded"
                        exit
                else
                    	echo -n "Login not OK - try again "
                        echo $CURRENTATTEMPT
                fi
        fi

	sleep 1
done

curl -f -s -k -b .sme_cookies https://$SERVERNNAME/server-manager/cgi-bin/useraccounts \
        -F acctName=$USERNAME -F page=4 -F page_stack=3 -F password1="$USERPASS" -F password2="$USERPASS" \
        -F Next=Save   > setpasswordresult.html
        sleep 1


cd $STARTDIR
rm -rf $WORKDIR

