#!/bin/bash

export BACKUP_HOME=/backup/database
export RESTORE_DIR=$BACKUP_HOME/restore
export BACKUP_PROGRAM=/usr/bin/xtrabackup
export CONFIG_FILE=/etc/mysql/my.cnf
export DBA_USER=root
export DBA_PASSWORD=PASSWORD
export DBA_HOST=localhost

function write_log() {
    msg="$(date '+%Y-%m-%d %H:%M:%S') INFO $1"
    if [ "$1" == "ERROR" ]; then
        msg="$(date '+%Y-%m-%d %H:%M:%S') ERROR $2"
    fi

    echo ${msg}
    echo ${msg} >>$BACKUP_HOME/restore.log
}

function usage() {
    echo "########################################"
    echo "Usage: $0 [full|inc]"
    echo "full: restore from full backup"
    echo "inc: restore from incremental backup"
    echo "########################################"

    exit 1
}

function full_restore() {
    write_log "begin full restore"
    write_log "restore directory is:$RESTORE_DIR"

    if [ ! -d $RESTORE_DIR ]; then
        write_log "restore dir:$RESTORE_DIR is not exist,begin create the directory..."
        mkdir -p $RESTORE_DIR
        write_log "restore dir created succeed!"
    fi

    echo "$BACKUP_PROGRAM --defaults-file=$CONFIG_FILE --user=$DBA_USER --password=$DBA_PASSWORD --host=$DBA_HOST --copy-back --target-dir=$RESTORE_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log"
    $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
        --user=$DBA_USER --password=$DBA_PASSWORD \
        --host=$DBA_HOST --copy-back \
        --target-dir=$RESTORE_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log

    if [ $? -eq 0 ]; then
        chown -R mysql:mysql $RESTORE_DIR
        write_log "full restore succeed!"
    else
        write_log "ERROR" "full restore failed!"
    fi
}

function incremental_restore() {
    write_log "begin incremental restore"
    write_log "restore directory is:$RESTORE_DIR"

    if [ ! -d $RESTORE_DIR ]; then
        write_log "restore dir:$RESTORE_DIR is not exist,begin create the directory..."
        mkdir -p $RESTORE_DIR
        write_log "restore dir created succeed!"
    fi

    local FULL_BACKUP_DIR=$BACKUP_HOME/backup/$1/full
    local INC_BACKUP_DIR=$BACKUP_HOME/backup/$1/inc

    echo "$BACKUP_PROGRAM --defaults-file=$CONFIG_FILE --user=$DBA_USER --password=$DBA_PASSWORD --host=$DBA_HOST --apply-log --redo-only --target-dir=$FULL_BACKUP_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log"
    $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
        --user=$DBA_USER --password=$DBA_PASSWORD \
        --host=$DBA_HOST --apply-log --redo-only \
        --target-dir=$FULL_BACKUP_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log

    if [ $? -eq 0 ]; then
        for inc in $(ls -tr $INC_BACKUP_DIR); do
            write_log "apply incremental backup $inc"
            $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
                --user=$DBA_USER --password=$DBA_PASSWORD \
                --host=$DBA_HOST --apply-log --redo-only \
                --incremental-dir=$INC_BACKUP_DIR/$inc --target-dir=$FULL_BACKUP_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log

            if [ $? -ne 0 ]; then
                write_log "ERROR" "apply incremental backup $inc failed!"
                exit 1
            fi
        done

        $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
            --user=$DBA_USER --password=$DBA_PASSWORD \
            --host=$DBA_HOST --apply-log --target-dir=$FULL_BACKUP_DIR 2>&1 | tee -a $BACKUP_HOME/restore.log

        if [ $? -eq 0 ]; then
            write_log "incremental restore succeed!"
            chown -R mysql:mysql $FULL_BACKUP_DIR
        else
            write_log "ERROR" "final apply log failed!"
            exit 1
        fi
    else
        write_log "ERROR" "full apply log failed!"
        exit 1
    fi
}

action=$1
id=$2

case $action in
full)
    write_log "begin full restore"
    full_restore
    write_log "full restore succeed!"
    ;;
inc)
    if [ -z "$id" ]; then
        write_log "ERROR" "incremental restore requires backup id"
        usage
    fi
    write_log "begin incremental restore with backup id $id"
    incremental_restore $id
    write_log "incremental restore succeed!"
    ;;
*)
    usage
    ;;
esac
