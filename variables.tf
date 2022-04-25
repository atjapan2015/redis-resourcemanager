## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_ocid" {}
variable "availablity_domain_name" {}

variable "redis_standalone_master_count" {
  description = "Number of master"
  type        = number
  default     = 1
}

variable "redis_masterslave_master_count" {
  description = "Number of master"
  type        = number
  default     = 1
}

variable "redis_masterslave_replica_count" {
  description = "Number of replicas"
  type        = number
  default     = 2
}

variable "redis_rediscluster_shared_count" {
  description = "Number of shareds"
  type        = number
  default     = 3
}

variable "redis_rediscluster_slave_count" {
  description = "Number of salves"
  type        = number
  default     = 1
}

variable "redis_deployment_type" {
  description = "Redis deployment type, available values [\"Standalone\", \"Master Slave\", \"Redis Cluster\"]"
  type        = string
  default     = "Standalone"
}

variable "redis_prefix" {
  default = "redis"
}

variable "redis_version" {
  default = "stable"
}

variable "redis_port1" {
  default = "6379"
}

variable "redis_port2" {
  default = "16379"
}

variable "sentinel_port" {
  default = "26379"
}

variable "redis_exporter_port" {
  default = "9121"
}

variable "redis_config_is_use_rdb" {
  description = "true for use rdb, false for not use rdb"
  type        = bool
  default     = true
}

variable "redis_config_is_use_aof" {
  description = "true for use aof, false for not use aof"
  type        = bool
  default     = false
}

variable "is_enable_backup" {
  description = "true for enable backup, false for diable backup"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  default = ""
}

variable "is_use_prometheus" {
  description = "true for use prometheus, false for not use prometheus"
  type        = bool
  default     = false
}

variable "prometheus_server" {
  default = "redismanager"
}

variable "prometheus_port" {
  default = "9091"
}

variable "is_use_grafana" {
  description = "true for use grafana, false for not use grafana"
  type        = bool
  default     = false
}

variable "grafana_server" {
  default = "redismanager"
}

variable "grafana_port" {
  default = "3000"
}

variable "grafana_user" {
  default = "admin"
}

variable "grafana_password" {
  default = ""
}

variable "s3_access_key" {
  default = ""
}

variable "s3_secret_key" {
  default = ""
}

variable "instance_os" {
  description = "Operating system for compute instances"
  default     = "Oracle Linux"
}

variable "linux_os_version" {
  description = "Operating system version for all Linux instances"
  default     = "7.9"
}

variable "instance_shape" {
  description = "Instance Shape"
  default     = "VM.Standard3.Flex"
}

variable "instance_flex_shape_ocpus" {
  default = 1
}

variable "instance_flex_shape_memory" {
  default = 8
}

variable "tag_value" {
  type    = object({ definedTags = map(any), freeformTags = map(any) })
  default = {
    definedTags  = {}
    freeformTags = {}
  }
}

variable "virtual_network_redis_vcn_id" {
  default = ""
}

variable "subnet_redis_subnet_id" {
  default = ""
}

# Dictionary Locals
locals {
  compute_flexible_shapes = [
    "VM.Standard.E4.Flex",
    "VM.Standard3.Flex"
  ]
}


# Checks if is using Flexible Compute Shapes
locals {
  is_flexible_node_shape = contains(local.compute_flexible_shapes, var.instance_shape)
}

