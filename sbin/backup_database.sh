#!/bin/bash

#
# 备份策略
#
# 1. 每周六进行完整备份
# 2. 每天进行增量备份
# 3. 每周六进行完整备份前，将上个周期的全备和增量备份进行压缩并迁移至历史备份目录
# 4. 每周六进行完整备份前，将上个周期的全备和增量备份迁移至历史备份目录
# 5. 保留最近30个周期的备份数据
#
# crontab配置
# 10 0 * * 6 /bin/bash /backup/database/backup_database.sh backup

export WEEK=$(date +%V)
export YEAR=$(date +%Y)
export WEEKDAY=$(date +%w)

export BACKUP_HOME=/backup/database
export BACKUP_HIST=$BACKUP_HOME/history
export BACKUP_LOG=$BACKUP_HOME/backup.log

[ ! -f $BACKUP_HOME/.id ] && echo ${WEEK} >$BACKUP_HOME/.id
export CURRENT_ID=$(cat "$BACKUP_HOME/.id")
export ID=$((CURRENT_ID + 1))

export BACKUP_DIR=$BACKUP_HOME/backup/${ID}
export BACKUP_FULL_DIR=$BACKUP_DIR/full
export BACKUP_INC_DIR=$BACKUP_DIR/inc

export BACKUP_PROGRAM=/usr/bin/xtrabackup
export CONFIG_FILE=/etc/mysql/my.cnf
export DBA_USER=root
export DBA_PASSWORD=PASSWORD
export DBA_HOST=localhost
export today=$(date +%Y%m%d)

function write_log() {
    msg="$(date '+%Y-%m-%d %H:%M:%S') INFO $1"
    if [ "$1" == "ERROR" ]; then
        msg="$(date '+%Y-%m-%d %H:%M:%S') ERROR $2"
    fi

    echo ${msg}
    echo ${msg} >>$BACKUP_LOG
}

# 全备数据迁移
function relocate_history_backup() {

    local LAST_BACKUP_HOME=$BACKUP_HOME/backup/${CURRENT_ID}
    local LAST_FULL_BACKUP_DIR=$LAST_BACKUP_HOME/full
    local LAST_INC_BACKUP_DIR=$LAST_BACKUP_HOME/inc

    write_log "begin relocate history backup"
    write_log "last full backup directory:$LAST_FULL_BACKUP_DIR"
    write_log "last incremental backup directory:$LAST_INC_BACKUP_DIR"

    if [ ! -d $LAST_FULL_BACKUP_DIR ]; then
        write_log "ERROR" "full backup dir:$LAST_FULL_BACKUP_DIR is not exist!"
    fi

    if [ ! -d $LAST_INC_BACKUP_DIR ]; then
        write_log "ERROR" "incremental backup dir:$LAST_INC_BACKUP_DIR is not exist!"
    fi

    if [ ! -d $LAST_FULL_BACKUP_DIR ] && [ ! -d $LAST_INC_BACKUP_DIR ]; then
        write_log "ERROR" "full backup dir:$LAST_FULL_BACKUP_DIR and incremental backup dir:$LAST_INC_BACKUP_DIR is not exist!"
        return
    fi

    [ ! -d $BACKUP_HIST ] && mkdir -p $BACKUP_HIST

    local now=$(date +%Y%m%d%H%M%S)
    if [ -d $LAST_FULL_BACKUP_DIR ]; then
        local full_backup_zip_file="full_${now}_${CURRENT_ID}.tar.gz"
        cd $LAST_BACKUP_HOME
        tar -zcvf $full_backup_zip_file full
        mv $full_backup_zip_file $BACKUP_HIST
        rm -rf full
    fi

    if [ -d $LAST_INC_BACKUP_DIR ]; then
        local inc_backup_zip_file="inc_${now}_${CURRENT_ID}.tar.gz"
        cd $LAST_BACKUP_HOME
        tar -zcvf $inc_backup_zip_file inc
        mv $inc_backup_zip_file $BACKUP_HIST
        rm -rf inc
    fi
    rm -rf $LAST_BACKUP_HOME

    write_log "relocate history backup succeed!"
}

function full_backup() {
    write_log "begin full backup"
    write_log "full backup dir is:$BACKUP_FULL_DIR"

    if [ ! -d $BACKUP_FULL_DIR ]; then
        write_log "full backup dir:$BACKUP_FULL_DIR is not exist,begin create the directory..."
        mkdir -p $BACKUP_FULL_DIR
        write_log "full backup dir created succeed!"
    fi

    echo "$BACKUP_PROGRAM --defaults-file=$CONFIG_FILE --user=$DBA_USER --password=$DBA_PASSWORD --host=$DBA_HOST --backup --target-dir=$BACKUP_FULL_DIR 2>&1 | tee -a $BACKUP_LOG"
    $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
        --user=$DBA_USER --password=$DBA_PASSWORD \
        --host=$DBA_HOST --backup \
        --target-dir=$BACKUP_FULL_DIR 2>&1 | tee -a $BACKUP_LOG
    if [ $? -eq 0 ]; then
        write_log "full backup succeed!"
    else
        write_log "ERROR" "full backup failed!"
    fi
}

function incremental_backup() {
    write_log "begin incremental backup"
    write_log "incremental backup dir is:$BACKUP_INC_DIR"

    if [ ! -d $BACKUP_INC_DIR ]; then
        write_log "incremental backup dir:$BACKUP_INC_DIR is not exist,begin create the directory..."
        mkdir -p $BACKUP_INC_DIR
        write_log "incremental backup dir created succeed!"
    fi

    # $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE --user=$DBA_USER --password=$DBA_PASSWORD --host=$DBA_HOST --backup --target-dir=$BACKUP_INC_DIR 2>&1 | tee -a $BACKUP_LOG
    $BACKUP_PROGRAM --defaults-file=$CONFIG_FILE \
    --user=$DBA_USER --password=$DBA_PASSWORD \
    --host=$DBA_HOST --backup \
    --target-dir=$BACKUP_INC_DIR/$today --incremental-basedir=$BACKUP_FULL_DIR

    if [ $? -eq 0 ]; then
        write_log "incremental backup succeed!"
    else
        write_log "ERROR" "incremental backup failed!"
    fi
}

function usage() {
    echo "########################################"
    echo "Usage: $0 [backup|full|inc|relocate]"
    echo "backup: backup database"
    echo "full: full backup"
    echo "inc: incremental backup"
    echo "relocate: relocate history backup"
    echo "########################################"

    exit 1
}

action=$1
case $action in
backup)
    write_log "begin backup database"
    if [ $WEEKDAY -eq 6 ]; then
        write_log "begin relocate history backup"
        relocate_history_backup
        write_log "relocate history backup succeed!"

        write_log "begin full backup"
        full_backup
        write_log "full backup succeed!"
    else
        write_log "begin incremental backup"
        incremental_backup
        write_log "incremental backup succeed!"
    fi

    if [ $WEEKDAY -eq 5 ]; then
        write_log "update backup id to $ID"
        echo $ID >$BACKUP_HOME/.id
    fi
    ;;
full)
    write_log "begin full backup"
    full_backup
    write_log "full backup succeed!"
    ;;
inc)
    write_log "begin incremental backup"
    incremental_backup
    write_log "incremental backup succeed!"
    ;;
relocate)
    write_log "begin relocate history backup"
    relocate_history_backup
    write_log "relocate history backup succeed!"
    ;;
*)
    usage
    ;;
esac
