:
# ForgetMeNot -- test if autobackup was performed last night 
# Author: Donald Bryson 
# For distribution by Sys Admin Magazine -- http://www.samag.com
# Last Revision Date: 7/31/97

# This script returns 4 valid exit values
#     1 -- Backup should not be checked today 
#     2 -- Backup was scheduled but not complete and the system is configured
#          to allow the user to log into the system anyway
#     3 -- Backup was scheduled and performed.
#     4 -- Backup was scheduled but not complete and the system is configured
#          to disallow logging into the system.

# **************************************************************************
# Read the configuration file and chnage to the our work directory
# You can store the configuration file in /etc/default or any other directory
configdir=/etc/default/

if [ -f "$configdir"CheckNBack.cfg ]
	then . "$configdir"CheckNBack.cfg
else
	echo "warning: CheckNBack.cfg not found"
	read Dummy 
	exit 1
fi

# ************************************************************************
# Check to see if the ForgetMeNot/CheckNBack system is disabled and exit
# if it is disabled.
if [ "$DISABLE" = "YES" ]
	then echo "ForgetMeNot/CheckNBack is disabled."
	exit 1
fi

# Change to the work directory of CheckNBack/ForgetMeNot
cd $CBDIR

# ************************************************************************
# Because the system is backing up via cron, the system having the
# correct date is very important.  This function gives the users the 
# opportunity to detect an incorrect system date
VerifyDate() {
	clear
	echo Please advise support if the current date and time is not
	echo "              " `date`
	echo
	echo "...Enter to continue"
	read Dummy
}

if [ "$VERIFYDATE" = "YES" ]
	then VerifyDate
fi

# ************************************************************************
# Calculate the date information and store into BackupTime and DayOfWeek
# BackupTime is used to compare the log entry in CheckNBack.log 
BackupTime=`date +%y%d%m`

# The day of the week as a number -- this is used to compare with 
# NOCHECK to disable checking on days that should not be checked
DayOfWeek=`date +%w`
# Check to see what days of the week to check the log
for nobd_day in $NOBACKUP 
do
	if [ $nobd_day -eq $DayOfWeek ]
		then echo "Backup should not be checked today."
		exit 1
	fi
done

# ************************************************************************
# The functions for giving warning or explaining why they can't log into
# the system
GiveWarning() {
	clear
	echo
	echo "     SCHEDULED BACKUP FAILED OR NOT ATTEMPTED!"
	echo
	echo "        CONTACT YOUR SUPPORT DEPARTMENT."
	echo
	echo "...Press ENTER to continue"
	read Dummy
}

ExplainNologin() {
	echo
	echo
	echo "You may not log into your system until problem is resolved."
	echo
	echo "...Press ENTER to continue"
	read Dummy
}

# ************************************************************************
# if NOLOGIN is is set to YES and there is an errror then the script returns
# 4 which is interpreted by the .profile as no login allowed.  If NOLOGIN
# is not set to YES then warn the user and return 2
# if the backup occured, return 3 which is interpreted by the .profile as
# no problem with backup.
echo "Checking your backup log for last night"
BackupProb() { 
	GiveWarning 
	if [ "$NOLOGIN" = "YES" ]
		then ExplainNologin
		if [ ! "$LOGNAME" = "root" ]
			then exit 4
		else
			echo "Allowing login anyway because you are root"
			read Dummy
			exit 2
		fi
		
	else
		GiveWarning
		exit 2
	fi
}

WASDONE=`grep $BackupTime CheckNBack.log` 

if [ ! "$WASDONE" ] 
	then BackupProb
else
	echo "Backup looks OK."
	exit 3
fi

