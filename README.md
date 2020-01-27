# backup-restic
Bash wrapper for restic, mainly used by me on Mac OS, but should be portable.

I think it's pretty self explanatory (and have sensible defaults), but feel free to provide feedback.

# Requirements
* Bash (duh)
* [Restic](https://github.com/restic/restic)
* Some vars in the config file (depending on the [backend](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html))

# Vars
The config file is stored at <HOME>/.config/restic-vars. Run backup-restic.sh once and it will tell you what is needed.

# Run
* Initialise: run the script once, then it will till you what to add to the vars file
* Run `backup-restic init` to initiate the repository
* To manually backup, `backup-restic backup`

# Run automatically
Add to your crontab, like so:
`@daily  /usr/local/bin/backup-restic backup >/dev/null 2>&1`

Works for me (tm)!
