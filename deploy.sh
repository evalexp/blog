#!/bin/bash

DEPLOY_DIR=/app/blog/html
BACKUP_DIR=/home/evalexp/backups/blog
USER_AND_GROUP=evalexp:evalexp

# prepare workspace
if [ ! -d $DEPLOY_DIR ]; then
    mkdir -p $DEPLOY_DIR
    chown -R $USER_AND_GROUP $DEPLOY_DIR
fi

if [ ! -d $BACKUP_DIR ]; then
    mkdir -p $BACKUP_DIR
    chown -R $USER_AND_GROUP $BACKUP_DIR
fi

# backup
time=$(date +%Y-%m-%d-%H:%M)
tar -czvf "$BACKUP_DIR/blog.$time.tar.gz" $DEPLOY_DIR

# clean old data
rm -rf $DEPLOY_DIR/*

# deploy
tar -zxvf /tmp/publish.tar.gz -C $DEPLOY_DIR
