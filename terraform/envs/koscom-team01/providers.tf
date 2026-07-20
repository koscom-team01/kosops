terraform {
  required_version = ">= 1.0.0"
  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = ">= 4.0.5"
    }
  }
}

provider "ncloud" {
  access_key  = var.ncloud_access_key
  secret_key  = var.ncloud_secret_key
  region      = var.ncloud_region
  site        = var.ncloud_site
  support_vpc = true
}
