#!/bin/sh 

cur_date=`date +%Y%m%d%H`
rm -rf /u01/redis_backup_snapshot/$cur_date/$(hostname)
mkdir -p /u01/redis_backup_snapshot/$cur_date/$(hostname)
cp /u01/redis_data/dump.rdb /u01/redis_backup_snapshot/$cur_date/$(hostname)

del_date=`date -d -48hour +%Y%m%d%H`
rm -rf /u01/redis_backup_snapshot/$del_date
