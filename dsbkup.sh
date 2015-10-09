#!/bin/bash

#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
#

. /opt/novell/eDirectory/bin/ndspath >/dev/null 2>&1

CDATE=$(date +%Y%m%d)
SERVER=$(hostname -s)
BACKUPFILE="${SERVER}${CDATE}"
BACKUPDIR="/var/backup"
RFLDIR="/var/backup/nds.rfl"
NDSD_LOG_FILE="/var/opt/novell/eDirectory/log/ndsd.log"
NICIPASSWD="yourpassword"
MAX_BACKUPS_TO_STORE=7
WAIT_FOR_BACKUP_SLEEP=15


function check_backup_dir_exists()
{
    [ ! -d ${BACKUPDIR} ] && return 1
    return 0
}

function check_rfl_dir_exists()
{
    [ ! -d ${RFLDIR} ] && return 1
    return 0
}

function take_backup()
{
    echo "* Starting backup of eDirectory on $SERVER ..."
    dsbk backup -b -f ${BACKUPDIR}/${BACKUPFILE}.bkup -l ${BACKUPDIR}/${BACKUPFILE}.log -e ${NICIPASSWD} -t -w
}

function check_backup_size()
{
    sum=0
    for f in $(ls -1 ${BACKUPDIR}/${BACKUPFILE}.bkup*);
    do
        size=$(ls -l $f | cut -d' ' -f5)
        sum=$(( $size + $sum ))
    done
    echo $sum
}

function create_tgz()
{
    # Archive files
    echo "* Archiving ${BACKUPFILE} and log file ..."
    if [ ${RFL_ENABLED} -eq 0 ];
    then
        tar zcvf ${BACKUPDIR}/${BACKUPFILE}.tgz ${BACKUPDIR}/${BACKUPFILE}.bkup* \
            ${BACKUPDIR}/${BACKUPFILE}.log $(_find_unused_rfl)
    else
        tar zcvf ${BACKUPDIR}/${BACKUPFILE}.tgz ${BACKUPDIR}/${BACKUPFILE}.bkup* \
            ${BACKUPDIR}/${BACKUPFILE}.log
    fi
}

_find_unused_rfl()
{
    CURRENT_RFL=$(tail -5 ${NDSD_LOG_FILE} | \
        grep "Current roll forward log" | tail -1 | awk '{ print $NF }')

    for unused_rfl in $(find ${RFLDIR} -type f ! -path ${RFLDIR}/${CURRENT_RFL});
    do
        lsof ${unused_rfl} >/dev/null 2>&1 || {
            echo ${unused_rfl}
        }
    done
}

delete_unused_rfl()
{
    dsbk getconfig >/dev/null 2>&1

    tail -10 ${NDSD_LOG_FILE} | \
        grep "Roll forward log status OFF" && \
            echo "* Roll forward logs are not enabled!" && return # Roll forward logs disabled. Do nothing.

    echo "* Deleting unused roll forward logs ..."
    _find_unused_rfl | while read unused_rfl;
                       do
                           echo " - ${unused_rfl} deleted"
                           rm -f ${unused_rfl}
                       done 
}

function delete_old_backup_files()
{
    # Delete unnecessary files
    echo "* Deleting temporary files ..."
    rm -f ${BACKUPDIR}/${BACKUPFILE}.bkup* ${BACKUPDIR}/${BACKUPFILE}.log

    # Delete files older than $MAX_BACKUPS_TO_STORE days
    echo "* Deleting files older than ${MAX_BACKUPS_TO_STORE} days ..."
    for delfile in $(find ${BACKUPDIR} -name '*.tgz' -mtime +${MAX_BACKUPS_TO_STORE});
    do
        echo " - ${delfile} deleted."
        rm -f ${delfile}
    done
}

function wait_for_backup_to_finish()
{
    # Check to see if backup is complete
    sleep ${WAIT_FOR_BACKUP_SLEEP}
    i=$(check_backup_size)
    sleep ${WAIT_FOR_BACKUP_SLEEP}
    i2=$(check_backup_size)

    while [ $i -ne $i2 ]
    do
        sleep ${WAIT_FOR_BACKUP_SLEEP}
        i=$(check_backup_size)
        sleep ${WAIT_FOR_BACKUP_SLEEP}
        i2=$(check_backup_size)
    done
}

function exit_with_errors()
{
    echo "**ERROR**: there were errors...Please, verify the output."
    exit 1
}

RFL_ENABLED=1
[ "$1" == "-rfl" ] && RFL_ENABLED=0

if ! check_backup_dir_exists ;
then
    echo "Directory ${BACKUPDIR} does not exist... exiting."
    exit 1
fi

if [ ${RFL_ENABLED} -eq 0 ];
then
    if ! check_rfl_dir_exists ;
    then
        echo "Directory ${RFLDIR} does not exist... exiting."
        echo "If you are going to use the 'roll-forward logs' feature, you should verify"
        echo "that it has been enabled and configured with the dsbk tool."
        exit 1
    fi
fi

cd ${BACKUPDIR}
take_backup && wait_for_backup_to_finish && create_tgz && \
    delete_old_backup_files
RET=$?

[ ${RET} -ne 0 ] && exit_with_errors

if [ ${RFL_ENABLED} -eq 0 ];
then
    delete_unused_rfl || exit_with_errors
fi

echo "* Backup script completed successfully."
