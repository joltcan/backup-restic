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

# Some default variables
ERROR=''
EXCLUDEFILE="$HOME/.config/restic-excludes"

# Now get your vars (and a big description if not)
VARSFILE="$HOME/.config/restic-vars"
if [ -f "$VARSFILE" ]
then
    source $VARSFILE
else
    cat << EOF

Hello! Restic vars are not set, please create $VARSFILE with the following content:

export RESTIC_PASSWORD="<encryption pass>"
export RESTIC_REPOSITORY=<repository url>
# and backend specific ones (I use s3-compatible storage with minio)
export AWS_ACCESS_KEY_ID=<s3 access key>
export AWS_SECRET_ACCESS_KEY=<s3 secret key>

#
## other options
# prune backups if run between these hours
# export PRUNE_START=01
# export PRUNE_STOP=05
#
# Run a script after
# export POSTRUN='unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY'
#
# Run a script for notifications, I use pushover app from pushover.net
# export NOTIFIER="curl -sL --form-string 'token=tokenkey' --form-string 'user=userkey' --form-string \"message=Restic failed on ${HOSTNAME} wi  th ${1}\" https://api.pushover.net/1/messages.json"
#
# Optional: Override cache file location if you want (I put them on fast storage)
#export XDG_CACHE_HOME=/share/Cache/restic
#export TMPDIR=/share/Cache/restic/tmp
# or read the [Restic documentation](http://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html) for more options.
EOF
    exit 1
fi

# set some defaults (if the aren't set in restic-vars file)
if [ -z ${ALWAYSUPDATEEXCLUDEFILE+x} ]; then ALWAYSUPDATEEXCLUDEFILE="TRUE" ; fi
if [ -z ${BACKUPPATH+x} ]; then BACKUPPATH=$HOME ; fi
if [ -z ${CHECK_DOM+x} ]; then CHECK_DOM="02" ; fi  # check the arkiv if it's this day-of-month
if [ -z ${LOCALEXCLUDE+x} ]; then LOCALEXCLUDE="" ; fi
if [ -z ${KEEP_DAILY+x} ]; then KEEP_DAILY=7 ; fi
if [ -z ${KEEP_WEEKLY+x} ]; then KEEP_WEEKLY=4 ; fi
if [ -z ${KEEP_MONTHLY+x} ]; then KEEP_MONTHLY=12 ; fi
if [ -z ${OPTIONS+x} ]; then OPTIONS=" --exclude-caches " ; fi  # exclude dirs with CACHEDIR.TAG file present (should contain "Signature: 8a477f597d28d172789f06886806bc5")
if [ -z ${POSTRUN+x} ]; then POSTRUN="" ; fi
if [ -z ${PRUNE_START+x} ]; then PRUNE_START="00" ; fi
if [ -z ${PRUNE_STOP+x} ]; then PRUNE_STOP="24" ; fi

# Try to be sensible with notifications. I mainly use this on OSX, but I'm trying to be nice here.
notification () {
    if [ "$NOTIFIER" != "" ]; then
        echo -n "Running notifier: "
            eval "${NOTIFIER}"
        echo "done."
    else
        PLATFORM=$(uname)
        if [ "$PLATFORM" == "Darwin" ]; then
            osascript -e "display notification \"$1\" with title \"Restic Error\""
        elif [ "$PLATFORM" == "Linux" ]; then
            if [ -f $(which xmessage) ] && [ ! -z ${DISPLAY} ]; then
                # notify via GUI
                xmessage "Restic error: ${1}"
            else
                echo "Restic error: ${1}"
            fi
        else
            # Report to syslog log if nothing else
            echo "Error: Restic: ${1}" | logger -p ERROR
        fi
    fi
}

# Download the excludefile
exclude_file (){
    curl -sSL -f -z $1 "https://gist.github.com/joltcan/451d7528455f3a350765c8160bb97e07/raw/" -o $1
}

# if we don't have the excludefile, then it's the first run
if [ ! -f $EXCLUDEFILE ]; then 
    # Get the excludefile
    exclude_file $EXCLUDEFILE
fi

# Update the excludefile (default)
[ "$ALWAYSUPDATEEXCLUDEFILE" == "TRUE" ] && exclude_file $EXCLUDEFILE

# Append a local excludefile to options if exist
[ "$LOCALEXCLUDE" != "" ] && OPTIONS+=" --exclude-file=$LOCALEXCLUDE "

case "$1" in
    init)
        # make it possible to init here
        restic -r $RESTIC_REPOSITORY init
        ((ERROR += $?))
        ;;
    backup)
        # Perform backup
        restic backup $OPTIONS --exclude-file=$EXCLUDEFILE $BACKUPPATH
        # Store there error here, so we can add errors later if needed.
        ((ERROR += $?))
        ;;
    check)
        restic check
        ((ERROR += $?))
        ;;
    forget)
        restic forget --prune --keep-daily=$KEEP_DAILY --keep-weekly=$KEEP_WEEKLY --keep-monthly=$KEEP_MONTHLY
        ((ERROR += $?))
        ;;
    unlock)
        restic unlock
        ((ERROR += $?))
        ;;
    prune)
        restic forget --prune --keep-daily=$KEEP_DAILY --keep-weekly=$KEEP_WEEKLY --keep-monthly=$KEEP_MONTHLY
        ((ERROR += $?))
        ;;
    rebuild-index)
        restic rebuild-index
        ((ERROR += $?))
        ;;
    *)
        echo "Usage: restic [backup|init|check|forget|prune|unlock/rebuild-index]"
        echo "For details, restic [item] --help"
        exit 1
esac

# Report errors
if [ $ERROR -eq 0 ]; then
    # Make sure we only clean old snapshots during night, regardless on when we run backup
    HOUR=$(date +%H)
    if [ $HOUR -gt $PRUNE_START ] && [ $HOUR -lt $PRUNE_STOP ]; then
        restic forget --prune --keep-daily=$KEEP_DAILY --keep-weekly=$KEEP_WEEKLY --keep-monthly=$KEEP_MONTHLY

        # report errors
        if [ $? -ne 0 ]; then
            notification "Restic Prune failed. Please investigate!" 
        fi

        # do a check if it's early day of month
        DOM=$(date +%d)
        if [ $DOM -eq $CHECK_DOM ]; then
            restic check

            # Report errors
            if [ $? -ne 0 ]; then
                notification "Restic Check failed. Please investigate!"
            fi
        fi
    fi
else
    notification "Restic Backup failed. Please investigate!"
fi

if [ "$POSTRUN" != "" ] && [ $ERROR -eq 0 ]; then
echo -n "Running post-script: "
    eval "$POSTRUN"
echo "Done."
fi

# Clean up:
unset RESTIC_PASSWORD
unset RESTIC_REPOSITORY
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset NOTIFIER

# Exit with the error code from above
exit $ERROR

