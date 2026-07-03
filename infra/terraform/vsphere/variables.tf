variable "vsphere_server" {
  type        = string
  description = "vCenter server FQDN or IP."
}

variable "vsphere_user" {
  type        = string
  description = "vSphere user."
}

variable "vsphere_password" {
  type        = string
  description = "vSphere password."
  sensitive   = true
}

variable "allow_unverified_ssl" {
  type        = bool
  description = "Allow self-signed vCenter certificates."
  default     = false
}

variable "datacenter" {
  type        = string
  description = "Existing vSphere datacenter name."
}

variable "cluster" {
  type        = string
  description = "Existing vSphere cluster name."
  default     = null
}

variable "datastore" {
  type        = string
  description = "Existing datastore name."
  default     = null
}

variable "network" {
  type        = string
  description = "Existing VM network name."
  default     = null
}

variable "vm_folder" {
  type        = string
  description = "Existing VM folder path."
  default     = null
}

variable "k3s_server_url" {
  type        = string
  description = "Existing K3S API endpoint, imported for inventory only."
  default     = null
}

variable "k3s_token" {
  type        = string
  description = "Existing K3S token, imported only when needed by operators."
  sensitive   = true
  default     = null
}
