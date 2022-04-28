## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "generated_ssh_private_key" {
  value     = tls_private_key.public_private_key_pair.private_key_pem
  sensitive = true
}

output "ssh_to_redis0" {
  description = "convenient command to ssh to the redis0 host"
  value       = "ssh -i id_rsa -o ServerAliveInterval=10 opc@${data.oci_core_vnic.redis_master_vnic[0].public_ip_address}"
}

output "redis_master_public_ip_address" {
  value = {for i in range((var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shard_count : var.redis_standalone_master_count)) : i => data.oci_core_vnic.redis_master_vnic[i].public_ip_address}
}

output "redis_master_private_ip_address" {
  value = {for i in range((var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shard_count : var.redis_standalone_master_count)) : i => data.oci_core_vnic.redis_master_vnic[i].private_ip_address}
}

output "redis_replica_public_ip_address" {
  value = (var.redis_deployment_type == "Standalone")? {for i in range(var.redis_standalone_master_count) : i => data.oci_core_vnic.redis_master_vnic[i].public_ip_address} : ({for i in range((var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count : var.redis_rediscluster_slave_count * var.redis_rediscluster_shard_count) : i => data.oci_core_vnic.redis_replica_vnic[i].public_ip_address})
}

output "redis_replica_private_ip_address" {
  value = (var.redis_deployment_type == "Standalone")? {for i in range(var.redis_standalone_master_count) : i => data.oci_core_vnic.redis_master_vnic[i].private_ip_address} : ({for i in range((var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count : var.redis_rediscluster_slave_count * var.redis_rediscluster_shard_count) : i => data.oci_core_vnic.redis_replica_vnic[i].private_ip_address})
}

output "redis_password" {
  value = random_string.redis_password.result
}