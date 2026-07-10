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
  region      = "KR"
  site        = "fin"   # 금융 클라우드 전용 API 엔드포인트 활성화
  support_vpc = true
}
