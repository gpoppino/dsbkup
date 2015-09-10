#!/bin/bash

. /opt/novell/eDirectory/bin/ndspath

CDATE=$(date +%Y%m%d)
SERVER=$(hostname -s)
BACKUPFILE="${SERVER}${CDATE}"
BACKUPDIR="/var/opt/novell/eDirectory/data/backup_edir"
NICIPASSWD="yourpassword"
MAX_BACKUPS_TO_STORE=7
WAIT_FOR_BACKUP_SLEEP=15


function check_backup_dir_exists()
{
    [ ! -d ${BACKUPDIR} ] && return 1
    return 0
}

function take_backup()
{
    echo "*  Starting backup of eDirectory on $SERVER ..."
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
    echo "*  Archiving ${BACKUPFILE} and log file ..."
    tar zcvf ${BACKUPDIR}/${BACKUPFILE}.tgz ${BACKUPDIR}/${BACKUPFILE}.bkup* ${BACKUPDIR}/${BACKUPFILE}.log
}

function delete_old_files()
{
    # Delete unnecessary files
    echo "*  Deleting temp files ..."
    rm -f ${BACKUPDIR}/${BACKUPFILE}.bkup* ${BACKUPDIR}/${BACKUPFILE}.log

    # Delete files older than $MAX_BACKUPS_TO_STORE days
    echo "*  Deleting files older than ${MAX_BACKUPS_TO_STORE} days ..."
    find ${BACKUPDIR} -name '*.tgz' -mtime +${MAX_BACKUPS_TO_STORE} >> /tmp/dsbackup.tmp
    cat /tmp/dsbackup.tmp | while read delfil
    do
        rm -f ${delfil}
    done
    [[ -s /tmp/dsbackup.tmp ]] && { rm /tmp/dsbackup.tmp ;}

    echo "*  Backup script complete."
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

if ! check_backup_dir_exists ;
then
    echo "Directory ${BACKUPDIR} does not exist... exiting."
    exit 1
fi


cd ${BACKUPDIR}
take_backup
wait_for_backup_to_finish
create_tgz
delete_old_files

