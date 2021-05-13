module "generate-cert" {
  source                  = "../generate-cert"
  organization_name       = var.organization_name
  ca_common_name          = var.ca_common_name
  common_name             = var.common_name
  dns_names               = var.dns_names
  validity_period_hours = var.validity_period_hours

}
