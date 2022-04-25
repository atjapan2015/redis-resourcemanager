## Copyright © 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Get the latest Oracle Linux image
data "oci_core_images" "InstanceImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape                    = var.instance_shape

  filter {
    name   = "display_name"
    values = ["^.*Oracle[^G]*$"]
    regex  = true
  }
}

data "template_file" "redis_rdb_copy_hourly_sh_template" {
  template = file( "./scripts/redis_rdb_copy_hourly.sh")
  vars     = {}
}

data "template_file" "redis_rdb_copy_daily_sh_template" {
  template = file( "./scripts/redis_rdb_copy_daily.sh")
  vars     = {}
}

data "template_file" "redis_rdb_restore_sh_template" {
  template = file( "./scripts/redis_rdb_restore.sh")
  vars     = {}
}

data "template_file" "redis_rdb_copy_hourly_daily_cron_template" {
  template = file( "./scripts/redis_rdb_copy_hourly_daily.cron")
  vars     = {}
}

data "template_file" "cloud_init_file" {
  template = file("./cloud_init/bootstrap.template.yaml")

  vars = {
    ssh_public_key                           = var.ssh_public_key
    redis_rdb_copy_hourly_sh_content         = base64gzip(data.template_file.redis_rdb_copy_hourly_sh_template.rendered)
    redis_rdb_copy_daily_sh_content          = base64gzip(data.template_file.redis_rdb_copy_daily_sh_template.rendered)
    redis_rdb_restore_sh_content             = base64gzip(data.template_file.redis_rdb_restore_sh_template.rendered)
    redis_rdb_copy_hourly_daily_cron_content = base64gzip(data.template_file.redis_rdb_copy_hourly_daily_cron_template.rendered)
  }
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "bootstrap.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_file.rendered
  }
}

data "template_file" "redis_bootstrap_master_template" {
  template = templatefile("./scripts/redis_bootstrap_master.tpl", {
    redis_deployment_type   = var.redis_deployment_type
    redis_prefix            = var.redis_prefix
    redis_domain            = data.oci_core_subnet.redis_subnet.dns_label
    redis_version           = var.redis_version
    redis_port1             = var.redis_port1
    redis_port2             = var.redis_port2
    sentinel_port           = var.sentinel_port
    redis_exporter_port     = var.redis_exporter_port
    redis_config_is_use_rdb = var.redis_config_is_use_rdb
    redis_config_is_use_aof = var.redis_config_is_use_aof
    is_use_prometheus       = var.is_use_prometheus
    s3_access_key           = var.s3_access_key
    s3_secret_key           = var.s3_secret_key
    redis_password          = random_string.redis_password.result
    master_private_ips      = data.oci_core_vnic.redis_master_vnic.*.private_ip_address
    master_public_ips       = data.oci_core_vnic.redis_master_vnic.*.public_ip_address
    master_fqdn             = data.oci_core_vnic.redis_master_vnic.*.hostname_label
  })
}

data "template_file" "redis_bootstrap_replica_template" {
  template = templatefile("./scripts/redis_bootstrap_replica.tpl", {
    redis_deployment_type   = var.redis_deployment_type
    redis_prefix            = var.redis_prefix
    redis_domain            = data.oci_core_subnet.redis_subnet.dns_label
    redis_version           = var.redis_version
    redis_port1             = var.redis_port1
    redis_port2             = var.redis_port2
    sentinel_port           = var.sentinel_port
    redis_exporter_port     = var.redis_exporter_port
    redis_config_is_use_rdb = var.redis_config_is_use_rdb
    redis_config_is_use_aof = var.redis_config_is_use_aof
    is_use_prometheus       = var.is_use_prometheus
    s3_access_key           = var.s3_access_key
    s3_secret_key           = var.s3_secret_key
    redis_password          = random_string.redis_password.result
    master_private_ips      = data.oci_core_vnic.redis_master_vnic.*.private_ip_address
    master_fqdn             = data.oci_core_vnic.redis_master_vnic.*.hostname_label
  })
}

data "oci_core_vnic_attachments" "redis_master_vnics" {
  count               = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shared_count : var.redis_standalone_master_count)
  compartment_id      = var.compartment_ocid
  availability_domain = var.availablity_domain_name
  instance_id         = oci_core_instance.redis_master[count.index].id
}

data "oci_core_vnic" "redis_master_vnic" {
  count   = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shared_count : var.redis_standalone_master_count)
  vnic_id = data.oci_core_vnic_attachments.redis_master_vnics[count.index].vnic_attachments.0.vnic_id
}

data "oci_core_vnic_attachments" "redis_replica_vnics" {
  count               = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count * var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")? var.redis_rediscluster_slave_count * var.redis_rediscluster_shared_count : 0)
  compartment_id      = var.compartment_ocid
  availability_domain = var.availablity_domain_name
  instance_id         = oci_core_instance.redis_replica[count.index].id
}

data "oci_core_vnic" "redis_replica_vnic" {
  count   = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count * var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")? var.redis_rediscluster_slave_count * var.redis_rediscluster_shared_count : 0)
  vnic_id = data.oci_core_vnic_attachments.redis_replica_vnics[count.index].vnic_attachments.0.vnic_id
}

data "oci_identity_region_subscriptions" "home_region_subscriptions" {
  tenancy_id = var.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = [true]
  }
}