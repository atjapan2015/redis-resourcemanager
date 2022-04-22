## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "oci_core_vcn" "redis_vcn" {
  vcn_id = var.virtual_network_redis_vcn_id
}

data "oci_core_subnet" "redis_subnet" {
  subnet_id = var.subnet_redis_subnet_id
}