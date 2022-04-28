## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_instance" "redis_master" {
  count               = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : ((var.redis_deployment_type == "Redis Cluster")?var.redis_rediscluster_shard_count : var.redis_standalone_master_count)
  availability_domain = length(data.oci_identity_availability_domains.ads.availability_domains) == 1 ? lookup(data.oci_identity_availability_domains.ads.availability_domains[0],"name") : lookup(data.oci_identity_availability_domains.ads.availability_domains[count.index % 3],"name")
  fault_domain        = "FAULT-DOMAIN-${count.index % 3 + 1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.redis_prefix}${count.index}"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flexible_node_shape ? [1] : []
    content {
      memory_in_gbs = var.instance_flex_shape_memory
      ocpus         = var.instance_flex_shape_ocpus
    }
  }

  create_vnic_details {
    subnet_id        = data.oci_core_subnet.redis_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "${var.redis_prefix}${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.InstanceImageOCID.images[0].id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.public_private_key_pair.public_key_openssh
    user_data           = data.template_cloudinit_config.cloud_init.rendered
  }

  freeform_tags = var.tag_value.freeformTags
  defined_tags  = var.tag_value.definedTags
}

