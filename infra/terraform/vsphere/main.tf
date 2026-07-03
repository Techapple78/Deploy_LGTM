data "vsphere_datacenter" "target" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "target" {
  count         = var.cluster == null ? 0 : 1
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.target.id
}

data "vsphere_datastore" "target" {
  count         = var.datastore == null ? 0 : 1
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.target.id
}

data "vsphere_network" "target" {
  count         = var.network == null ? 0 : 1
  name          = var.network
  datacenter_id = data.vsphere_datacenter.target.id
}

resource "vsphere_tag_category" "k3s" {
  name        = "k3s"
  cardinality = "MULTIPLE"
  description = "Tags for existing K3S virtual machines."

  associable_types = [
    "VirtualMachine",
  ]
}

resource "vsphere_tag" "observability" {
  name        = "observability"
  category_id = vsphere_tag_category.k3s.id
  description = "VM participates in the K3S observability platform."
}
