variable "rg_name" {
  type    = string
}

locals {
  project     = "kube_Test_Project"
  owner       = "ITs"
  environment = "Dev"
}

variable "kubernetesvm" {

  type    = string
  default = "kubernetesvm"
}

variable "nw_name" {
  type    = string

}

variable "vm_size" {
  type    = string
  default = "Standard_B2ms"
}

variable "home_exernal_ip" {
  type    = string

}


locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Project     = local.project
    Owner       = local.owner
    Environment = local.environment
  }
}


# variable "organization_name" {
#   description = "The name of the organization to associate with the certificates (e.g. Acme Co)."
#   default = "kube Test"
# }

# variable "ca_common_name" {
#   description = "The common name to use in the subject of the CA certificate (e.g. acme.co cert)."
# }

# variable "common_name" {
#   description = "The common name to use in the subject of the certificate (e.g. acme.co cert)."
# }

# variable "dns_names" {
#   description = "List of DNS names for which the certificate will be valid (e.g. foo.example.com)."
#   type        = list(any)
# }


# variable "validity_period_hours" {
#   description = "The number of hours after initial issuing that the certificate will become invalid."
#   default = 1200
# }


variable "public_key_openssh" {
  description = "tls_private_key resource"
}