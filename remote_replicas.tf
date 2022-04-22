## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "redis_replica_bootstrap" {
  depends_on = [oci_core_instance.redis_master, oci_core_instance.redis_replica]
  count = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count : ((var.redis_deployment_type == "Redis Cluster")? var.redis_rediscluster_slave_count * var.redis_rediscluster_shared_count : 0)
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_replica_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      agent       = false
      timeout     = "10m"
    }

    content     = data.template_file.redis_bootstrap_replica_template.rendered
    destination = "/home/opc/redis_bootstrap_replica.sh"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_replica_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "chmod +x ~/redis_bootstrap_replica.sh",
      "sudo ~/redis_bootstrap_replica.sh",
      "sudo chmod 777 /etc/redis.conf",
      "if [[ '${var.redis_deployment_type}' == 'Master Slave' ]] && [[ `hostname -s` != '${data.oci_core_vnic.redis_master_vnic[0].hostname_label}' ]]; then echo 'slaveof ${data.oci_core_vnic.redis_master_vnic[0].public_ip_address} ${var.redis_port1}' >> /etc/redis.conf; fi",
      "sudo chmod 644 /etc/redis.conf",
      "if [[ ${var.redis_config_is_use_rdb} == true ]] && [[ ${var.is_enable_backup} == true ]]; then sudo crontab /u01/redis_backup_tools/redis_rdb_copy_hourly_daily.cron; fi"
    ]
  }
}