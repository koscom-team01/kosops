output "bastion_public_ip" {
  value       = ncloud_public_ip.bastion_ip.public_ip
  description = "SSH Bastion Host Public IP Address"
}

output "rke2_cp_private_ip" {
  value       = ncloud_server.rke2_cp.private_ip
  description = "RKE2 Control Plane Server Private IP Address"
}

output "api_lb_domain" {
  value       = ncloud_lb.api_lb.domain
  description = "K8s API Server Load Balancer Domain Name (Port 6443)"
}

output "rke2_token" {
  value       = random_password.rke2_token.result
  sensitive   = true
  description = "RKE2 Cluster Join Shared Token"
}

output "ssh_login_key_decrypted" {
  value       = "ncloud_login_key로 생성한 개인키(*.pem)는 로컬에 안전하게 보관하세요."
  description = "Key guide"
}
