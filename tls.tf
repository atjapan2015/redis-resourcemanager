## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "tls_private_key" "public_private_key_pair" {
  algorithm   = "RSA"
}

resource "local_file" "id_rsa" {
  content  = tls_private_key.public_private_key_pair.private_key_pem
  filename = "id_rsa"
  file_permission = "600"
}