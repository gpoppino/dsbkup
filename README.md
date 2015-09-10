# Overview

This is a wrapper script for the tool *dsbk* used to take backups of eDirectory.
It takes the backup and stores the resulting files in a **.tgz.** tar gzipped
file and cleans the directory.

If the script is run many times, it deletes *.tgz* files older than
`MAX_BACKUPS_TO_STORE` days.

## Setup

To configure the script, you will have to edit it and change a few variables in
its header. These are:

- `BACKUPDIR`: this specifies where to store the backup files.
- `NICIPASSWD`: this variable holds a password used to take the NICI files
  backup. You will need the same password to perform a restore of these files.
- `MAX_BACKUPS_TO_STORE`: how many backuped up *.tgz.* files to store in
  *BACKUPDIR* before removing them.

The name of the backup file will be like *myserver20151009.tgz*, where myserver
is the name of the server and 20151009 is the date when the backup was taken. If
there are more than one backups taken in a day, the previous one will be
overwritten.

## Notes

1. This script has been tested with eDirectory 8.8.7 and 8.8.8.
2. If the path of the script *ndspath* is changed in a future version of
eDirectory, it will have to be updated in the header of this script to the new
path.

