#!/bin/sh
echo "[Backup List]"
if [[ $(ls -l /u01/redis_backup_snapshot/ | grep '^d' | wc -l) == 0 ]]; then
  echo "No backup file"
  exit 0
fi
ls -l /u01/redis_backup_snapshot/ | grep '^d' | awk '{print $9}'
read -p "Which backup do you want to restore? Please input the directory name: " directory
if [[ -f "/u01/redis_backup_snapshot/$directory/dump.rdb" ]]; then
  echo "/u01/redis_backup_snapshot/$directory/dump.rdb will be restored"
else
  echo "The directory name is wrong, please run it again."
  exit 0
fi

read -p "Are you sure to stop redis now or cancel the restore process? Restore or Cancel: " answer
[ "$answer" == "Restore" ] &&{
  echo "stopping redis, please wait..."
  systemctl stop redis
  echo "redis stopped"
  yes | cp /u01/redis_backup_snapshot/$directory/dump.rdb /u01/redis_data/dump.rdb
  echo "dump.rdb restored"
  if [[ -f "/u01/redis_data/appendonly.aof" ]]; then
    sed -i 's/^appendonly yes$/#appendonly yes/' /etc/redis.conf
    echo "set #appendonly yes to redis.conf"
    yes | rm /u01/redis_data/appendonly.aof
    echo "appendonly.aof deleted"
    echo "starting redis, please wait..."
    systemctl start redis
    echo "redis started"
    redis_password=$(grep requirepass /etc/redis.conf | awk '{print $2}')
    redis_password=$(echo $redis_password | sed "s/\"//g")
    /usr/local/bin/redis-cli -a $redis_password config set appendonly yes
    echo "set appendonly yes via redis-cli"
    echo "stopping redis, it takes time depengding on your data volumn, please wait..."
    systemctl stop redis
    if [[ $(systemctl status redis | grep failed | wc -l) == 1 ]]; then
      echo "Restore process failed. Please try it again."
      exit 0
    fi
    echo "redis stopped"
    sed -i 's/^#appendonly yes$/appendonly yes/' /etc/redis.conf
    echo "set appendonly yes to redis.conf"
  fi
  echo "starting redis, please wait..."
  systemctl start redis
  echo "redis started"
  echo "Restore process completed."
  exit 0
}
[ "$answer" == "Cancel" ] &&{
  echo "Cancel this restore process."
  exit 0
}
[[ "$answer" != "Restore" ]] && [[ "$answer" != "Cancel" ]] &&{
  echo "Wrong input, please run it again."
  exit 0
}