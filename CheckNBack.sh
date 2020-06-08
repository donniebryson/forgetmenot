:
# CheckNBack -- tar backup script that checks for operator negligence
# Author: Donald Bryson dbryson@tclock.com -- http://www.tclock.com
# For distribution by Sys Admin Magazine -- http://www.samag.com
# Last Revision Date: 7/31/97

BackupTime=`date +%y%d%m`
DayOfWeek=`date +%w`

# This holds the status of the backup.  Because there has not been an
# error condition yet, we are setting it to 0.

StatusOfBackup=0

# ************************************************************************
# Read CheckNBack.cfg, the configuration file, then load parameters.

# The variable, configdir, contains the directory that stores CheckNBack.cfg. 
# This variable allows you to store CheckNBack in any directory.  However,
# most SAs will expect a file like this in /etc/default/
# Note: the script assumes the directory ends with "/".

configdir=/etc/default/

# NagNoConfig(): notifies root that CheckNBack is not setup correctly.
NagNoConfig() {
	echo "CheckNBack could not find CheckNBack.cfg." > /tmp/rmesg.txt
	echo "CheckNBack thought the file was in " "$configdir" >> /tmp/rmesg.txt
	echo "This means the backup did not run last night" >> /tmp/rmesg.txt
	cat /tmp/rmesg.txt | mail -s "MAJOR BACKUP PROBLEM" root
}

# The use of the "." causes the configuration file to be included in the 
# current script
if [ -f "$configdir"CheckNBack.cfg ]
	then . "$configdir"CheckNBack.cfg
else
	NagNoConfig
	exit 1
fi

# ************************************************************************
# Check to see if the ForgetMeNot/CheckNBack system is disabled and exit
# if it is disabled.
# Note the use of ">" to redirect the output to the CheckNBack.err file. 
# ">" will create the file if it doesn't exist and overwrite the
# file if it does exist. The >> appends the output to CheckNBack.err file
# and will not overwrite an existing file.

if [ "$DISABLE" = "YES" ]
	then echo "CheckNBack disabled on " > CheckNBack.err
	date >> CheckNBack.err
	exit 2
fi

# Change to the CheckNBack/ForgetMeNot work directory. This directory is
# defined in CheckNBack.cfg

cd $CBDIR

# ************************************************************************
# NagTapeNotChanged(): Notify that last night's tape is still in the drive 
# It does two things:
# 1. Notifies the manager that the tape has not been changed
# 2. Set the StatusOfBackup flag to 1 which prohibits logging this days
#    backup.  Everyone on the system will know there has been a problem.

NagTapeNotChanged() {
	cat tchange.txt | mail -s "TAPE NOT CHANGED" "$BACKMGR" 
# StatusOfBackup=1
}

# ************************************************************************
# Check if the operator is changing tapes.
# This is done by the yearday being stored in the l_backup (last night's
# backup) on disk and t_backup ( tonight's backup) file on the tape.  If the 
# two numbers are the same, then the tape has not been changed since 
# the previous backup.

# copy yesterdays t_backup (today's backup) to l_backup (last backup)
cp t_backup l_backup

$TARRESTORE t_backup 

# Create a new t_backup based on the day of the year
date +%j > t_backup

# diff returns 0 if there are no differences between two files.  
# The && is is a logical AND.  NagTpeNotChanged is executed if and only if
# diff returns 0.

diff l_backup t_backup && NagTapeNotChanged 

# ************************************************************************
# Actually do the backup -- note that the SA can check CheckNBack.err 
# for misc. tar errors.  It is also e-mails that file to the BACKMGR
# for review.

# NagTarErr(): Notify everyone that the tar command generated an error
# message.
NagTarErr() {
	cat nowrite.txt CheckNBack.err | mail -s "BACKUP PROBLEM" "$BACKMGR" 
	StatusOfBackup=1		
}

# If the tar backup generates an error, then execute the NagTarErr function.
# Note that stderr is redirected to CheckNBack.err by using "2>".  
# This allows the script to capture error messages so they may be e-mailed 
# BACKMGR.

$TARBACKUP $BACKUPDIR t_backup 2> CheckNBack.err || NagTarErr

# ************************************************************************
# First make sure you can read the backup tape after you create the
# archive.  

# NogNoGood(): notify BACKMGR and everyone else (via the log file) that
# this backup is no good because you cannot read the tape after it was
# created.

NagNoGood() {
	cat noread.txt | mail -s "COULD NOT READ BACKUP" "$BACKMGR" 
	StatusOfBackup=2		
}

# this is a temporary file that will be the same as t_backup.
cp t_backup tmpflag

# restore one file from the tape and check for errors.  No errors means 
# the tape can be read, not that the backup occured.
$TARRESTORE t_backup || NagNoGood

# compare that one file with what we expect it to be.  Because t_backup
# changes every night, if t_backup is the same as tmpflag then we know
# the tape contains todays data.

diff tmpflag t_backup || NagNoGood
rm tmpflag

# ************************************************************************
# Also make check that the number of files are the same on the HD
# and the tape if CHECKFILECOUNT is set to YES.

NagNumDiff() {
	cat numdiff.txt | mail -s "FILES DIFFERENT" "$BACKMGR" 
	StatusOfBackup=3		
}

if [ "$CHECKFILECOUNT" = "YES" ]

	then NumOnBack=`$TARLIST | wc -l`

# tar file contains the t_backup file which is not contained in the 
# data directory so we deduct one file from the tar file count

	NumOnBack=`expr $NumOnBack - 1`

# Notice the "!" in front of the "-type d" in the find command.  That 
# indicates that the find command should return only files but not 
# directories. 

	NumOnDisk=`find $BACKUPDIR ! -type d -print | wc -l`

	if [ ! "$NumOnBack" -eq "$NumOnDisk" ]
		then NagNumDiff		
	fi

fi

# ************************************************************************
# If the archive and read is OK then set the log for todays date
if [ $StatusOfBackup -eq 0 ]
	then echo $BackupTime >> CheckNBack.log
fi

exit 0 
