#!/bin/bash

# Created by github.com/joltcan
# Please report errors via github, and contribute if you want to.
# I mainly use this on my laptop to minio (s3 compatible storage), but feel free 
# to use how you please. Find the latest version at https://github.com/joltcan/backup-restic
# Install restic with homebrew on OSX: ```brew upgrade && brew install restic```
# (C) Fredrik Lundhag, 2018

# This program is free software: you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, 
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with 
# this program. If not, see http://www.gnu.org/licenses/.

VARSFILE="$HOME/.config/restic-vars"
if [ -f "$VARSFILE" ]
then
    source $VARSFILE
else
    echo "Restic vars are not set, please create $VARSFILE with the following content:
export RESTIC_PASSWORD=<encryption pass>
export RESTIC_REPOSITORY=<repository url>
and backend specific ones
export AWS_ACCESS_KEY_ID=<s3 access key>
export AWS_SECRET_ACCESS_KEY=<s3 secret key>
 or read the restic documentation for more options: http://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html"
    exit 1
fi

# set some defaults if unset
if [ -z ${BACKUPPATH+x} ]; then BACKUPPATH=$HOME ; fi
if [ -z ${OPTIONS+x} ]; then OPTIONS="" ; fi
if [ -z ${POSTSCRIPT+x} ]; then POSTSCRIPT="" ; fi

# Defaults
ERROR=False
EXCLUDEFILE="$HOME/.config/restic-excludes"
FIRSTRUN=""
LOCALEXCLUDE="$HOME/.config/restic-exclude-local" # Create to add to the defaults.

# Try to be sensible with notifications. I mainly use this on OSX, but I'm trying to be nice here.
notification () {
    PLATFORM=$(uname)
    if [ "$PLATFORM" == "Darwin" ]; then
        osascript -e "display notification \"$1\" with title \"Restic Error\""
    elif [ "$PLATFORM" == "Linux" ]; then
        if xhost 2>&1 /dev/null ; then
            xmessage "Restic error: $1"
        fi
    else
        # Report to syslog log if nothing else
        echo "Error: Restic: $1" | logger -p ERROR
    fi
}

# if we dont' have the excludefile, then it's the first run
[ ! -f $EXCLUDEFILE ] && FIRSTRUN=1

# Download the excludefile
curl -sSL -f -z $EXCLUDEFILE "https://gist.github.com/joltcan/451d7528455f3a350765c8160bb97e07/raw/" -o $EXCLUDEFILE

# Append a local exclude file to options if exist
[ -f $LOCALEXCLUDE ] && OPTIONS+="--exclude-file=$LOCALEXCLUDE"

# If it is the first run, init backend
if [ "$FIRSTRUN" == "1" ]; then restic -r $RESTIC_REPOSITORY init ; fi

# Perform backup
restic backup $OPTIONS --exclude-file=$EXCLUDEFILE $BACKUPPATH
# Report errors
if [ ! $? -eq 0 ]; then
    notification "Backup failed. Please investigate!"
    ERROR=True
fi

if [ "$ERROR" == "False" ]; then
    # Make sure we only clean old snapshots during night, regardless on when we run backup
    HOUR=$(date +%H)
    if [ $HOUR -gt 01 ] && [ $HOUR -lt 05 ]; then
        restic forget --prune --keep-daily=7 --keep-weekly=4 --keep-monthly=24  

        # report errors
        if [ ! $? -eq 0 ]; then
            notification "Prune failed. Please investigate!" 
        fi

        # do a check if it's early day of month
        DOM=$(date +%d)
        if [ $DOM == "02" ]; then
            restic check

            # Report errors
            if [ ! $? -eq 0 ]; then
                notification "Check failed. Please investigate!"
            fi
        fi
    fi
fi

if [ "$POSTSCRIPT" != "" ]; then
    POSTRUN=$($POSTSCRIPT)
fi

# Clean up:
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset RESTIC_PASSWORD
unset RESTIC_REPOSITORY
