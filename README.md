# backup-restic
Bash wrapper for restic, mainly used by me on Mac OS, but should be portable.

I think it's pretty self explanatory (and have sensible defaults), but feel free to provide feedback.

# Requirements
* Bash (duh)
* [Restic](https://github.com/restic/restic)
* Some vars in the config file (depending on the [backend](http://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.htm))

# Vars
The config file is stored at <HOME>/.config/restic-vars. Run backup-restic.sh once and it will tell you what is needed.


Works for me (tm)!