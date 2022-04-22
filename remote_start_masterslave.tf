## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "redis_master_start_redis_masterslave" {
  depends_on = [null_resource.redis_master_bootstrap, null_resource.redis_replica_bootstrap]
  count      = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : 0
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
      "echo '=== Starting REDIS on redis${count.index} node... ==='",
      "sudo systemctl start redis.service",
      "sleep 5",
      "sudo systemctl status redis.service",
      "echo '=== Started REDIS on redis${count.index} node... ==='",
      "if [[ ${var.is_use_prometheus} == true ]] ; then echo '=== Register REDIS Exporter to Prometheus... ==='; fi",
      "if [[ ${var.is_use_prometheus} == true ]] ; then curl -X GET http://${var.prometheus_server}:${var.prometheus_port}/prometheus/targets/add/${data.oci_core_vnic.redis_master_vnic[count.index].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}_${var.redis_exporter_port}; fi"
    ]
  }
}

resource "null_resource" "redis_replica_start_redis_masterslave" {
  depends_on = [null_resource.redis_master_start_redis_masterslave]
  count      = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count : 0
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
      "echo '=== Starting REDIS on redis${count.index + var.redis_masterslave_master_count} node... ==='",
      "sudo systemctl start redis.service",
      "sleep 5",
      "sudo systemctl status redis.service",
      "echo '=== Started REDIS on redis${count.index + var.redis_masterslave_master_count} node... ==='",
      "if [[ ${var.is_use_prometheus} == true ]] ; then echo '=== Register REDIS Exporter to Prometheus... ==='; fi",
      "if [[ ${var.is_use_prometheus} == true ]] ; then curl -X GET http://${var.prometheus_server}:${var.prometheus_port}/prometheus/targets/add/${data.oci_core_vnic.redis_replica_vnic[count.index].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}_${var.redis_exporter_port}; fi"
    ]
  }
}

resource "null_resource" "redis_master_start_sentinel_masterslave" {
  depends_on = [null_resource.redis_replica_start_redis_masterslave]
  count      = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_master_count : 0
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
      "echo '=== Starting REDIS SENTINEL on redis${count.index} node... ==='",
      "sudo systemctl enable sentinel.service",
      "sudo systemctl start sentinel.service",
      "sleep 5",
      "sudo systemctl status sentinel.service",
      "echo '=== Started REDIS SENTINEL on redis${count.index} node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_start_sentinel_masterslave" {
  depends_on = [null_resource.redis_master_start_sentinel_masterslave]
  count      = (var.redis_deployment_type == "Master Slave") ? var.redis_masterslave_replica_count : 0
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
      "echo '=== Starting REDIS SENTINEL on redis${count.index + var.redis_masterslave_master_count} node... ==='",
      "sudo systemctl enable sentinel.service",
      "sudo systemctl start sentinel.service",
      "sleep 5",
      "sudo systemctl status sentinel.service",
      "echo '=== Started REDIS SENTINEL on redis${count.index + var.redis_masterslave_master_count} node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_register_grafana_masterslave" {
  depends_on = [null_resource.redis_replica_start_sentinel_masterslave]
  count      = (var.redis_deployment_type == "Master Slave") ? 1 : 0
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "if [[ ${var.is_use_grafana} == true ]] ; then echo '=== Register REDIS Datasource to Grafana... ==='; fi",
      "if [[ ${var.is_use_grafana} == true ]] ; then curl -X DELETE http://${var.grafana_user}:${var.grafana_password}@${var.grafana_server}:${var.grafana_port}/api/datasources/name/${data.oci_core_vnic.redis_master_vnic[0].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}; fi",
      "if [[ ${var.is_use_grafana} == true ]] ; then curl -d '{\"name\":\"${data.oci_core_vnic.redis_master_vnic[0].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}\",\"type\":\"redis-datasource\",\"typeName\":\"Redis\",\"typeLogoUrl\":\"public/plugins/redis-datasource/img/logo.svg\",\"access\":\"proxy\",\"url\":\"redis://${data.oci_core_vnic.redis_master_vnic[0].private_ip_address}:${var.sentinel_port}\",\"password\":\"\",\"user\":\"\",\"database\":\"\",\"basicAuth\":false,\"isDefault\":false,\"jsonData\":{\"client\":\"sentinel\",\"sentinelAcl\":false,\"sentinelName\":\"${data.oci_core_vnic.redis_master_vnic[0].hostname_label}.${data.oci_core_vcn.redis_vcn.dns_label}\"},\"secureJsonData\":{\"password\":\"${random_string.redis_password.result}\"},\"readOnly\":false}' -H \"Content-Type: application/json\" -X POST http://${var.grafana_user}:${var.grafana_password}@${var.grafana_server}:${var.grafana_port}/api/datasources; fi"
    ]
  }
}