#!/bin/bash

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
    if [ ${RFL_ENABLED} -eq 0 ];
    then
        tar zcvf ${BACKUPDIR}/${BACKUPFILE}.tgz ${BACKUPDIR}/${BACKUPFILE}.bkup* \
            ${BACKUPDIR}/${BACKUPFILE}.log ${RFLDIR}/*.log
    else
        tar zcvf ${BACKUPDIR}/${BACKUPFILE}.tgz ${BACKUPDIR}/${BACKUPFILE}.bkup* \
            ${BACKUPDIR}/${BACKUPFILE}.log
    fi
}

delete_unused_rfl()
{
    dsbk getconfig >/dev/null 2>&1

    tail -10 ${NDSD_LOG_FILE} | \
        grep "Roll forward log status OFF" && \
            echo "* Roll forward logs are not enabled!" && return # Roll forward logs disabled. Do nothing.

    LAST_RFL_NOT_USED=$(tail -5 ${NDSD_LOG_FILE} | \
        grep "Last roll forward log not used" | tail -1 | awk '{ print $NF }')
    for rfl_not_used in $(find ${RFLDIR} ! -newer ${RFLDIR}/${LAST_RFL_NOT_USED} ! -path ${RFLDIR}/${LAST_RFL_NOT_USED});
    do
        lsof ${rfl_not_used} >/dev/null 2>&1 || {
            echo " - deleting unused roll forward log ${rfl_not_used}"
            rm -f ${rfl_not_used}
        }

    done
}

function delete_old_backup_files()
{
    # Delete unnecessary files
    echo "* Deleting temp files ..."
    rm -f ${BACKUPDIR}/${BACKUPFILE}.bkup* ${BACKUPDIR}/${BACKUPFILE}.log

    # Delete files older than $MAX_BACKUPS_TO_STORE days
    echo "*  Deleting files older than ${MAX_BACKUPS_TO_STORE} days ..."
    find ${BACKUPDIR} -name '*.tgz' -mtime +${MAX_BACKUPS_TO_STORE} >> /tmp/dsbackup.tmp
    cat /tmp/dsbackup.tmp | while read delfil
    do
        echo " - ${delfil} deleted."
        rm -f ${delfil}
    done
    [[ -s /tmp/dsbackup.tmp ]] && { rm /tmp/dsbackup.tmp ;}
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
take_backup
wait_for_backup_to_finish
create_tgz
delete_old_backup_files
[ ${RFL_ENABLED} -eq 0 ] && delete_unused_rfl

echo "*  Backup script complete."
