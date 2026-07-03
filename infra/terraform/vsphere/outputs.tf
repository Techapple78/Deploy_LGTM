output "datacenter_id" {
  value       = data.vsphere_datacenter.target.id
  description = "Resolved vSphere datacenter ID."
}

output "observability_tag_id" {
  value       = vsphere_tag.observability.id
  description = "Tag ID for K3S observability VMs."
}

output "cluster_id" {
  value       = try(data.vsphere_compute_cluster.target[0].id, null)
  description = "Resolved vSphere cluster ID when provided."
}

output "datastore_id" {
  value       = try(data.vsphere_datastore.target[0].id, null)
  description = "Resolved datastore ID when provided."
}

output "network_id" {
  value       = try(data.vsphere_network.target[0].id, null)
  description = "Resolved network ID when provided."
}
