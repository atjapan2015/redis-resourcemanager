## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "redis_master_bootstrap" {
  depends_on = [oci_core_instance.redis_master]
  count      = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shared_count : var.redis_standalone_master_count)
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      agent       = false
      timeout     = "10m"
    }

    content     = data.template_file.redis_bootstrap_master_template.rendered
    destination = "/home/opc/redis_bootstrap_master.sh"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "chmod +x ~/redis_bootstrap_master.sh",
      "sudo ~/redis_bootstrap_master.sh",
      "if [[ ${var.redis_config_is_use_rdb} == true ]] && [[ ${var.is_enable_backup} == true ]]; then sudo crontab /u01/redis_backup_tools/redis_rdb_copy_hourly_daily.cron; fi"
    ]
  }
}