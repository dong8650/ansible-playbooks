#!/bin/bash

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/etc/ansible/results/$TIMESTAMP"
cd /etc/ansible

# 백업 디렉토리 생성
mkdir -p "$BACKUP_DIR"

# ansible-playbook 실행
ansible-playbook -i inventory roles/config-backup/playbook.yml -e "backup_dir=$BACKUP_DIR"

# git 커밋 및 push
cd results
git add .
git commit -m "Config backup: $TIMESTAMP"
git push origin main

