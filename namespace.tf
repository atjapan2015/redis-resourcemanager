data "oci_objectstorage_namespace" "ns" {
  #Optional
  compartment_id = var.compartment_ocid
}