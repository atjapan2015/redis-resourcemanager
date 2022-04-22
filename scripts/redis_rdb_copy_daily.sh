#!/bin/sh 

cur_date=`date +%Y%m%d`
rm -rf /u01/redis_backup_snapshot/$cur_date
mkdir /u01/redis_backup_snapshot/$cur_date
cp /u01/redis_data/dump.rdb /u01/redis_backup_snapshot/$cur_date

del_date=`date -d -1month +%Y%m%d`
rm -rf /u01/redis_backup_snapshot/$del_date