# Overview

This is a wrapper script for the tool *dsbk* used to take backups of eDirectory.
It takes the backup and stores the resulting files in a **.tgz** tar gzipped
file and cleans the directory.

If the script is run many times, it deletes *.tgz* files older than
`MAX_BACKUPS_TO_STORE` days.

## Setup

To configure the script, you will have to edit it and change a few variables in
its header. These are:

- `BACKUPDIR`: this specifies where to store the backup files.
- `NICIPASSWD`: this variable holds a password used to take the NICI files
  backup. You will need the same password to perform a restore of these files.
- `MAX_BACKUPS_TO_STORE`: how many backed up *.tgz* files to store in
  *BACKUPDIR* before removing them.

If you have the roll-forward logs feature enabled and want to backup the last
unused log files before deleting them, you will have to specify the directory
where these logs are stored with the following variable:

- `RFLDIR`: name of the directory where the roll-forward logs are stored.

Start the script with the option *-rfl* to enable this feature to run.

The name of the backup file will be like *myserver20151009.tgz*, where myserver
is the name of the server and 20151009 is the date when the backup was taken. If
there are more than one backups taken in a day, the previous one will be
overwritten.

## Notes

1. This script has been tested with eDirectory 8.8.7 and 8.8.8.
2. If the path of the script *ndspath* is changed in a future version of
eDirectory, it will have to be updated in the header of this script to the new
path.

# License and Disclaimer

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see http://www.gnu.org/licenses/.

