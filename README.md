# backup-restic
Bash wrapper for restic, mainly used by me on Mac OS and Linux, but should be portable, feedback welcome!

I think it's pretty self explanatory (and have sensible defaults), but feel free to provide feedback.

# Requirements

* [Restic](https://github.com/restic/restic)
* Some vars in the config file (depending on the [backend](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html))

# Vars
The config file is stored at `$HOME/.config/restic-vars`. Run backup-restic.sh once and it will tell you what is needed if something is missing.

This is mine:
```bash
export RESTIC_REPOSITORY=s3:https://< a nice minio node/bucket>
export RESTIC_PASSWORD=<great pass> # created when you run backup-restic init when you have set the repository url>
export AWS_ACCESS_KEY_ID=<access key for minio/s3>
export AWS_SECRET_ACCESS_KEY=<secret key>
export LOCALEXCLUDE="$HOME/.config/restic-exclude-local" # sometimes defaults aren't enough
export BACKUPPATH="$HOME /Volumes/usbdisk"
# export NOTIFIER="curl -sL --form-string 'token=apptoken' --form-string 'user=usertoken' --form-string \"message=Restic failed on ${HOSTNAME} with ${1}\" https://api.pushover.net/1/messages.json >/dev/null" # I like pushover.net
```

# Run

* Initialise: run the script once, then it will till you what to add to the vars file
* Run `backup-restic init` to initiate the repository
* To manually backup, `backup-restic backup`

# Run automatically
Add to your crontab, like so:
`@daily  /usr/local/bin/backup-restic backup >/dev/null 2>&1`

Works for me (tm)!
