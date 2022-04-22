## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "redis_master_start_redis_rediscluster" {
  depends_on = [null_resource.redis_master_bootstrap, null_resource.redis_replica_bootstrap]
  count      = (var.redis_deployment_type == "Redis Cluster") ? var.redis_rediscluster_shared_count : 0
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

resource "null_resource" "redis_replica_start_redis_rediscluster" {
  depends_on = [null_resource.redis_master_start_redis_rediscluster]
  count      = (var.redis_deployment_type == "Redis Cluster") ? var.redis_rediscluster_slave_count * var.redis_rediscluster_shared_count : 0
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
      "echo '=== Starting REDIS on redis${count.index + var.redis_rediscluster_shared_count} node... ==='",
      "sudo systemctl start redis.service",
      "sleep 5",
      "sudo systemctl status redis.service",
      "echo '=== Started REDIS on redis${count.index + var.redis_rediscluster_shared_count} node... ==='",
      "if [[ ${var.is_use_prometheus} == true ]] ; then echo '=== Register REDIS Exporter to Prometheus... ==='; fi",
      "if [[ ${var.is_use_prometheus} == true ]] ; then curl -X GET http://${var.prometheus_server}:${var.prometheus_port}/prometheus/targets/add/${data.oci_core_vnic.redis_replica_vnic[count.index].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}_${var.redis_exporter_port}; fi"
    ]
  }
}

resource "null_resource" "redis_master_master_list_rediscluster" {
  depends_on = [null_resource.redis_replica_start_redis_rediscluster]
  count      = (var.redis_deployment_type == "Redis Cluster") ? var.redis_rediscluster_shared_count : 0
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh${count.index}.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting Create Master List on redis0 node... ==='",
      "sleep 10",
      "echo -n '${data.oci_core_vnic.redis_master_vnic[count.index].private_ip_address}:${var.redis_port1} ' >> /home/opc/master_list.sh",
      "echo -n '' > /home/opc/replica_list.sh",
      "echo '=== Started Create Master List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_replica_list_rediscluster" {
  depends_on = [null_resource.redis_master_master_list_rediscluster]
  count      = (var.redis_deployment_type == "Redis Cluster") ? var.redis_rediscluster_slave_count * var.redis_rediscluster_shared_count : 0
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh${count.index}.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting Create Replica List on redis0 node... ==='",
      "sleep 10",
      "echo -n '${data.oci_core_vnic.redis_replica_vnic[count.index].private_ip_address}:${var.redis_port1} ' >> /home/opc/replica_list.sh",
      "echo '=== Started Create Replica List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_create_cluster_rediscluster" {
  depends_on = [null_resource.redis_replica_replica_list_rediscluster]
  count      = (var.redis_deployment_type == "Redis Cluster") ?  1 : 0
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
      "echo '=== Create REDIS CLUSTER from redis0 node... ==='",
      "sudo -u root /usr/local/bin/redis-cli --cluster create `cat /home/opc/master_list.sh` `cat /home/opc/replica_list.sh` -a ${random_string.redis_password.result} --cluster-replicas ${var.redis_rediscluster_slave_count} --cluster-yes",
      "echo '=== Cluster REDIS created from redis0 node... ==='",
      "echo 'cluster info' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}",
      "echo 'cluster nodes' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}",
    ]
  }
}

resource "null_resource" "redis_master_register_grafana_rediscluster" {
  depends_on = [null_resource.redis_master_create_cluster_rediscluster]
  count      = (var.redis_deployment_type == "Redis Cluster") ? 1 : 0
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
      "if [[ ${var.is_use_grafana} == true ]] ; then curl -d '{\"name\":\"${data.oci_core_vnic.redis_master_vnic[0].hostname_label}.${data.oci_core_subnet.redis_subnet.dns_label}\",\"type\":\"redis-datasource\",\"typeName\":\"Redis\",\"typeLogoUrl\":\"public/plugins/redis-datasource/img/logo.svg\",\"access\":\"proxy\",\"url\":\"redis://${data.oci_core_vnic.redis_master_vnic[0].private_ip_address}:${var.redis_port1}\",\"password\":\"\",\"user\":\"\",\"database\":\"\",\"basicAuth\":false,\"isDefault\":false,\"jsonData\":{\"client\":\"cluster\"},\"secureJsonData\":{\"password\":\"${random_string.redis_password.result}\"},\"readOnly\":false}' -H \"Content-Type: application/json\" -X POST http://${var.grafana_user}:${var.grafana_password}@${var.grafana_server}:${var.grafana_port}/api/datasources; fi"
    ]
  }
}