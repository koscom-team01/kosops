variable "ncloud_access_key" {
  type        = string
  description = "Naver Cloud Platform Access Key"
  sensitive   = true
}

variable "ncloud_secret_key" {
  type        = string
  description = "Naver Cloud Platform Secret Key"
  sensitive   = true
}

variable "admin_ip" {
  type        = string
  description = "개발자/운영자 공인 IP 대역 (Bastion SSH 및 K8s API 인바운드 허용 용도)"
  default     = "0.0.0.0/0"
}

variable "login_key_name" {
  type        = string
  description = "VM 로그인에 사용할 NCP 로그인 키 이름"
  default     = "team1-kosops-key"
}

variable "zone_kr1" {
  type        = string
  description = "배포할 가용 영역 1 (Zone 1)"
  default     = "KR-1"
}

variable "zone_kr2" {
  type        = string
  description = "배포할 가용 영역 2 (Zone 2)"
  default     = "KR-2"
}

variable "ncloud_site" {
  type        = string
  description = "Naver Cloud Platform Site (public 또는 fin)"
  default     = "public"
}

variable "ncloud_region" {
  type        = string
  description = "Naver Cloud Platform Region (KR 또는 FKR)"
  default     = "KR"
}

variable "zone" {
  type        = string
  description = "Placeholder legacy zone parameter to silence tfvars warnings"
  default     = "KR-1"
}

variable "fin_server_product_code" {
  type        = string
  description = "금융 클라우드 가상 서버 상품 스펙 코드 (1세대)"
  default     = "SVR.VSVR.STAND.C002.M008.NET.SSD.B050.G001"
}
