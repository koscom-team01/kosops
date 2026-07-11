# 1. OS 이미지 및 서버 사양 조회 (Rocky Linux 8.x 및 스펙)
data "ncloud_server_images" "images" {
  filter {
    name   = "product_name"
    values = ["Rocky Linux 8.*"]
    regex  = true
  }
}

data "ncloud_server_products" "bastion_spec" {
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  filter {
    name   = "product_code"
    values = ["SSD"]
    regex  = true
  }
  filter {
    name   = "cpu_count"
    values = ["2"]
  }
  filter {
    name   = "memory_size"
    values = ["4GB"]
  }
  filter {
    name   = "product_type"
    values = ["HICPU"]
  }
}

data "ncloud_server_products" "cp_spec" {
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  filter {
    name   = "product_code"
    values = ["SSD"]
    regex  = true
  }
  filter {
    name   = "cpu_count"
    values = ["2"]
  }
  filter {
    name   = "memory_size"
    values = ["8GB"]
  }
  filter {
    name   = "product_type"
    values = ["STAND"]
  }
}

data "ncloud_server_products" "dp_spec" {
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  filter {
    name   = "product_code"
    values = ["SSD"]
    regex  = true
  }
  filter {
    name   = "cpu_count"
    values = ["2"]
  }
  filter {
    name   = "memory_size"
    values = ["8GB"]
  }
  filter {
    name   = "product_type"
    values = ["STAND"]
  }
}

# 2. VPC 및 서브넷 구성 (Multi-AZ 6개 서브넷 + NATGW 전용 서브넷)
resource "ncloud_vpc" "vpc" {
  name            = "hackathon"
  ipv4_cidr_block = "192.168.0.0/16"
}

# NAT Gateway용 PUBLIC NATGW 서브넷 (Zone KR-1)
resource "ncloud_subnet" "team1_nat_sub" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.0.0/24"
  zone           = var.zone_kr1
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "NATGW"
  name           = "team1-nat-sub"
}

# Bastion용 Public Subnet 1 (Zone KR-1)
resource "ncloud_subnet" "team1_pub_kr1" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.1.0/24"
  zone           = var.zone_kr1
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "GEN"
  name           = "team1-pub-kr1"
}

# 로드밸런서용 Public Subnet 1 (Zone KR-1)
resource "ncloud_subnet" "team1_lb_kr1" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.2.0/24"
  zone           = var.zone_kr1
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "LOADB"
  name           = "team1-lb-kr1"
}

# 로드밸런서용 Public Subnet 2 (Zone KR-2)
resource "ncloud_subnet" "team1_lb_kr2" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.3.0/24"
  zone           = var.zone_kr2
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "LOADB"
  name           = "team1-lb-kr2"
}

# RKE2 Control Plane용 Private Subnet 1 (Zone KR-1)
resource "ncloud_subnet" "team1_pri_kr1" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.4.0/24"
  zone           = var.zone_kr1
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  usage_type     = "GEN"
  name           = "team1-pri-kr1"
}

# RKE2 Data Plane용 Private Subnet 2 (Zone KR-2)
resource "ncloud_subnet" "team1_pri_kr2" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.5.0/24"
  zone           = var.zone_kr2
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  usage_type     = "GEN"
  name           = "team1-pri-kr2"
}

# DB용 Private Subnet 1 (Zone KR-1)
resource "ncloud_subnet" "team1_db_kr1" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.6.0/24"
  zone           = var.zone_kr1
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  usage_type     = "GEN"
  name           = "team1-db-kr1"
}

# DB용 Private Subnet 2 (Zone KR-2)
resource "ncloud_subnet" "team1_db_kr2" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "192.168.7.0/24"
  zone           = var.zone_kr2
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  usage_type     = "GEN"
  name           = "team1-db-kr2"
}

# 3. NAT Gateway 및 라우팅 테이블
resource "ncloud_nat_gateway" "nat_gw" {
  vpc_no    = ncloud_vpc.vpc.id
  subnet_no = ncloud_subnet.team1_nat_sub.id
  zone      = var.zone_kr1
  name      = "hackathon-m-ng01"
}

# Public 서브넷용 라우팅 테이블
resource "ncloud_route_table" "team1_pub_rt" {
  vpc_no                = ncloud_vpc.vpc.id
  supported_subnet_type = "PUBLIC"
  name                  = "team1-pub-rt"
}

resource "ncloud_route_table_association" "pub_rta_nat" {
  route_table_no = ncloud_route_table.team1_pub_rt.id
  subnet_no      = ncloud_subnet.team1_nat_sub.id
}

resource "ncloud_route_table_association" "pub_rta_pub" {
  route_table_no = ncloud_route_table.team1_pub_rt.id
  subnet_no      = ncloud_subnet.team1_pub_kr1.id
}

resource "ncloud_route_table_association" "pub_rta_lb1" {
  route_table_no = ncloud_route_table.team1_pub_rt.id
  subnet_no      = ncloud_subnet.team1_lb_kr1.id
}

resource "ncloud_route_table_association" "pub_rta_lb2" {
  route_table_no = ncloud_route_table.team1_pub_rt.id
  subnet_no      = ncloud_subnet.team1_lb_kr2.id
}

# Private 서브넷용 라우팅 테이블 및 NAT Gateway 라우팅 설정
resource "ncloud_route_table" "team1_pri_rt" {
  vpc_no                = ncloud_vpc.vpc.id
  supported_subnet_type = "PRIVATE"
  name                  = "team1-pri-rt"
}

resource "ncloud_route" "team1_pri_route_to_nat" {
  route_table_no         = ncloud_route_table.team1_pri_rt.id
  destination_cidr_block = "0.0.0.0/0"
  target_type            = "NATGW"
  target_name            = ncloud_nat_gateway.nat_gw.name
  target_no              = ncloud_nat_gateway.nat_gw.id
}

resource "ncloud_route_table_association" "pri_rta_pri1" {
  route_table_no = ncloud_route_table.team1_pri_rt.id
  subnet_no      = ncloud_subnet.team1_pri_kr1.id
}

resource "ncloud_route_table_association" "pri_rta_pri2" {
  route_table_no = ncloud_route_table.team1_pri_rt.id
  subnet_no      = ncloud_subnet.team1_pri_kr2.id
}

resource "ncloud_route_table_association" "pri_rta_db1" {
  route_table_no = ncloud_route_table.team1_pri_rt.id
  subnet_no      = ncloud_subnet.team1_db_kr1.id
}

resource "ncloud_route_table_association" "pri_rta_db2" {
  route_table_no = ncloud_route_table.team1_pri_rt.id
  subnet_no      = ncloud_subnet.team1_db_kr2.id
}

# 4. Access Control Groups (ACG) 보안 그룹 설정
# Bastion Host용 ACG
resource "ncloud_access_control_group" "bastion_acg" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "team1-bastion-acg"
}

resource "ncloud_access_control_group_rule" "bastion_rules" {
  access_control_group_no = ncloud_access_control_group.bastion_acg.id

  inbound {
    protocol   = "TCP"
    ip_block   = var.admin_ip
    port_range = "22"
  }

  outbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "1-65535"
  }
}

# RKE2 Control Plane (CP)용 ACG
resource "ncloud_access_control_group" "cp_acg" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "team1-rke2-cp-acg"
}

resource "ncloud_access_control_group_rule" "cp_rules" {
  access_control_group_no = ncloud_access_control_group.cp_acg.id

  # Bastion으로부터의 SSH 허용
  inbound {
    protocol              = "TCP"
    source_access_control_group_no = ncloud_access_control_group.bastion_acg.id
    port_range            = "22"
  }

  # VPC 대역(192.168.0.0/16) 내부 K8s API 및 Node Registration 허용
  inbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16"
    port_range = "6443"
  }

  inbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16"
    port_range = "9345"
  }

  # 개발자 IP로부터의 직접 K8s API 통신 허용 (API 로드밸런서 접속용)
  inbound {
    protocol   = "TCP"
    ip_block   = var.admin_ip
    port_range = "6443"
  }

  # RKE2 내부 etcd 및 CNI 오버레이 통신 허용 (VPC 내부)
  inbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16"
    port_range = "10250" # Kubelet
  }

  inbound {
    protocol   = "UDP"
    ip_block   = "192.168.0.0/16"
    port_range = "8472"  # Canal/Flannel VXLAN
  }

  inbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16"
    port_range = "2379-2380" # etcd
  }

  outbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "1-65535"
  }

  outbound {
    protocol   = "UDP"
    ip_block   = "0.0.0.0/0"
    port_range = "1-65535"
  }
}

# RKE2 Data Plane (DP)용 ACG
resource "ncloud_access_control_group" "dp_acg" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "team1-rke2-dp-acg"
}

resource "ncloud_access_control_group_rule" "dp_rules" {
  access_control_group_no = ncloud_access_control_group.dp_acg.id

  # Bastion으로부터의 SSH 허용
  inbound {
    protocol              = "TCP"
    source_access_control_group_no = ncloud_access_control_group.bastion_acg.id
    port_range            = "22"
  }

  # RKE2 CNI 및 Kubelet 통신 허용 (VPC 내부)
  inbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16"
    port_range = "10250"
  }

  inbound {
    protocol   = "UDP"
    ip_block   = "192.168.0.0/16"
    port_range = "8472"
  }

  # Ingress HTTP/HTTPS 트래픽 전달용 포트 개방 (NLB 소스 IP 보존을 지원하기 위해 외부 통신 전체 개방)
  inbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "80"
  }

  inbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "443"
  }

  outbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "1-65535"
  }

  outbound {
    protocol   = "UDP"
    ip_block   = "0.0.0.0/0"
    port_range = "1-65535"
  }
}

# Load Balancer용 ACG
resource "ncloud_access_control_group" "lb_acg" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "team1-lb-acg"
}

resource "ncloud_access_control_group_rule" "lb_rules" {
  access_control_group_no = ncloud_access_control_group.lb_acg.id

  # 외부 웹 접속 허용
  inbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "80"
  }

  inbound {
    protocol   = "TCP"
    ip_block   = "0.0.0.0/0"
    port_range = "443"
  }

  # K8s API 외부 호출 허용 (관리자 IP로 한정)
  inbound {
    protocol   = "TCP"
    ip_block   = var.admin_ip
    port_range = "6443"
  }

  outbound {
    protocol   = "TCP"
    ip_block   = "192.168.0.0/16" # VPC 내부 백엔드로만 전송 허용
    port_range = "1-65535"
  }
}

# 5. 로그인 키 및 개인키 파일 로컬 저장
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "ncloud_login_key" "key" {
  key_name = var.login_key_name
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../../../team1-kosops-key.pem"
  file_permission = "0600"
}

# 5.1 RKE2 CP 서버 초기화 스크립트 정의
resource "random_string" "init_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "ncloud_init_script" "rke2_cp_init" {
  name    = "team1-rke2-cp-init-${random_string.init_suffix.result}"
  content = <<EOF
#!/bin/bash
# Enable SSH key authentication (Auto-injected since NCP VPC doesn't inject it for root)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${tls_private_key.ssh_key.public_key_openssh}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Disable SELinux and firewalld (Required for Rocky Linux 8)
setenforce 0 || true
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
systemctl stop firewalld || true
systemctl disable firewalld || true

# RKE2 Server Auto-Installation & Configuration
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="server" sh -

mkdir -p /etc/rancher/rke2/
cat > /etc/rancher/rke2/config.yaml << EOL
write-kubeconfig-mode: "0644"
token: "${random_string.rke2_token.result}"
tls-san:
  - "team1-rke2-cp"
  - "${ncloud_lb.api_lb.domain}"
kubelet-arg:
  - "fail-cgroupv1=false"
EOL

# Register Harbor Private Registry with hwangonjang.com
cat > /etc/rancher/rke2/registries.yaml << EOL
mirrors:
  "harbor.hwangonjang.com":
    endpoint:
      - "https://harbor.hwangonjang.com"
EOL

systemctl enable rke2-server.service
systemctl start rke2-server.service
EOF
}

# 5.2 RKE2 DP 에이전트 초기화 스크립트 정의
resource "ncloud_init_script" "rke2_dp_init" {
  name    = "team1-rke2-dp-init-${random_string.init_suffix.result}"
  content = <<EOF
#!/bin/bash
# Enable SSH key authentication (Auto-injected since NCP VPC doesn't inject it for root)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${tls_private_key.ssh_key.public_key_openssh}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Disable SELinux and firewalld (Required for Rocky Linux 8)
setenforce 0 || true
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
systemctl stop firewalld || true
systemctl disable firewalld || true

# RKE2 Agent Auto-Installation & Join to Control Plane
# Wait for CP server to initialize
sleep 60

curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -

mkdir -p /etc/rancher/rke2/
cat > /etc/rancher/rke2/config.yaml << EOL
server: "https://${ncloud_network_interface.cp_nic.private_ip}:9345"
token: "${random_string.rke2_token.result}"
kubelet-arg:
  - "fail-cgroupv1=false"
EOL

# Register Harbor Private Registry with hwangonjang.com
cat > /etc/rancher/rke2/registries.yaml << EOL
mirrors:
  "harbor.hwangonjang.com":
    endpoint:
      - "https://harbor.hwangonjang.com"
EOL

systemctl enable rke2-agent.service
systemctl start rke2-agent.service
EOF
}

# 5.2.1 Bastion 서버 초기화 스크립트 정의
resource "ncloud_init_script" "bastion_init" {
  name    = "team1-bastion-init-${random_string.init_suffix.result}"
  content = <<EOF
#!/bin/bash
# Enable SSH key authentication (Auto-injected since NCP VPC doesn't inject it for root)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "${tls_private_key.ssh_key.public_key_openssh}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
EOF
}

# 5.3 Network Interfaces (Bastion, CP) - NCP VPC 환경에서는 ACG 부착을 위해 별도 NIC 생성이 필수적임
resource "ncloud_network_interface" "bastion_nic" {
  name                  = "team1-bastion-nic"
  subnet_no             = ncloud_subnet.team1_pub_kr1.id
  access_control_groups = [ncloud_access_control_group.bastion_acg.id]
}

resource "ncloud_network_interface" "cp_nic" {
  name                  = "team1-rke2-cp-nic"
  subnet_no             = ncloud_subnet.team1_pri_kr1.id
  private_ip            = cidrhost(ncloud_subnet.team1_pri_kr1.subnet, 11)
  access_control_groups = [ncloud_access_control_group.cp_acg.id]
}

# 6. 컴퓨팅 인스턴스 (Bastion, CP)
resource "ncloud_server" "bastion" {
  subnet_no                 = ncloud_subnet.team1_pub_kr1.id
  name                      = "team1-bastion"
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  server_product_code       = data.ncloud_server_products.bastion_spec.server_products[0].product_code
  login_key_name            = ncloud_login_key.key.key_name
  init_script_no            = ncloud_init_script.bastion_init.id

  network_interface {
    network_interface_no = ncloud_network_interface.bastion_nic.id
    order                = 0
  }
}

resource "ncloud_public_ip" "bastion_ip" {
  server_instance_no = ncloud_server.bastion.id
}

# RKE2 클러스터 공유 비밀 토큰 자동 생성
resource "random_string" "rke2_token" {
  length  = 32
  special = false
}

# RKE2 Control Plane (CP) 서버 기동
resource "ncloud_server" "rke2_cp" {
  subnet_no                 = ncloud_subnet.team1_pri_kr1.id
  name                      = "team1-rke2-cp"
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  server_product_code       = data.ncloud_server_products.cp_spec.server_products[0].product_code
  login_key_name            = ncloud_login_key.key.key_name
  init_script_no            = ncloud_init_script.rke2_cp_init.id

  network_interface {
    network_interface_no = ncloud_network_interface.cp_nic.id
    order                = 0
  }

  depends_on = [ncloud_lb.api_lb]
}

# 7. Data Plane (DP) Auto Scaling Group (ASG) 구성
# Launch Configuration 설정
resource "random_id" "dp_lc_suffix" {
  byte_length = 4
  keepers = {
    init_script_id = ncloud_init_script.rke2_dp_init.id
    image_code     = data.ncloud_server_images.images.server_images[0].product_code
    product_code   = data.ncloud_server_products.dp_spec.server_products[0].product_code
  }
}

resource "ncloud_launch_configuration" "dp_lc" {
  name                      = "team1-rke2-dp-lc-${random_id.dp_lc_suffix.hex}"
  server_image_product_code = data.ncloud_server_images.images.server_images[0].product_code
  server_product_code       = data.ncloud_server_products.dp_spec.server_products[0].product_code
  login_key_name            = ncloud_login_key.key.key_name
  init_script_no            = ncloud_init_script.rke2_dp_init.id

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group 정의
resource "ncloud_auto_scaling_group" "dp_asg" {
  name                    = "team1-rke2-dp-asg"
  launch_configuration_no = ncloud_launch_configuration.dp_lc.id
  subnet_no               = ncloud_subnet.team1_pri_kr2.id
  min_size                = 2
  max_size                = 4
  desired_capacity        = 2
  health_check_type_code  = "SVR"
  access_control_group_no_list = [ncloud_access_control_group.dp_acg.id]

  target_group_list = [
    ncloud_lb_target_group.web_http_tg.target_group_no,
    ncloud_lb_target_group.web_https_tg.target_group_no
  ]
}

# ASG 룰 정의 (Scale-Out / Scale-In 정책 정의)
resource "ncloud_auto_scaling_policy" "scale_out" {
  name                  = "team1-scale-out-policy"
  auto_scaling_group_no = ncloud_auto_scaling_group.dp_asg.id
  adjustment_type_code  = "CHANG"
  scaling_adjustment    = 1
  cooldown              = 300
}

resource "ncloud_auto_scaling_policy" "scale_in" {
  name                  = "team1-scale-in-policy"
  auto_scaling_group_no = ncloud_auto_scaling_group.dp_asg.id
  adjustment_type_code  = "CHANG"
  scaling_adjustment    = -1
  cooldown              = 300
}

# 8. Load Balancers (NLB for K8s API Server)
# RKE2 API 통신을 위한 Public Network Load Balancer (NLB) 생성 (KR-1 및 KR-2 LB 서브넷 2개 배치)
resource "ncloud_lb" "api_lb" {
  name           = "team1-api-lb"
  network_type   = "PUBLIC"
  type           = "NETWORK"
  subnet_no_list = [ncloud_subnet.team1_lb_kr1.id]
}

# Target Group (CP 6443 포트 연동)
resource "ncloud_lb_target_group" "api_tg" {
  vpc_no      = ncloud_vpc.vpc.id
  protocol    = "TCP"
  target_type = "VSVR"
  port        = 6443
  name        = "team1-api-tg"

  health_check {
    protocol       = "TCP"
    port           = 6443
    cycle          = 30
    up_threshold   = 2
    down_threshold = 2
  }
}

resource "ncloud_lb_target_group_attachment" "api_tg_attach" {
  target_group_no = ncloud_lb_target_group.api_tg.id
  target_no_list  = [ncloud_server.rke2_cp.id]
}

# Listener (6443)
resource "ncloud_lb_listener" "api_listener" {
  load_balancer_no = ncloud_lb.api_lb.id
  protocol         = "TCP"
  port             = 6443
  target_group_no  = ncloud_lb_target_group.api_tg.id
}

# 9. Web Service Load Balancer (HTTP: 80 / HTTPS: 443)
# 외부 웹 서비스 인그레스(Ingress) 트래픽 전달용 퍼블릭 네트워크 로드밸런서(NLB) 개설
resource "ncloud_lb" "web_lb" {
  name           = "team1-web-lb"
  network_type   = "PUBLIC"
  type           = "NETWORK"
  subnet_no_list = [ncloud_subnet.team1_lb_kr1.id]
}

# Web HTTP 대상 그룹 (RKE2 노드의 hostPort 80 바인딩)
resource "ncloud_lb_target_group" "web_http_tg" {
  vpc_no      = ncloud_vpc.vpc.id
  protocol    = "TCP"
  target_type = "VSVR"
  port        = 80
  name        = "team1-web-http-tg"

  health_check {
    protocol       = "TCP"
    port           = 80
    cycle          = 30
    up_threshold   = 2
    down_threshold = 2
  }
}

# Web HTTPS 대상 그룹 (RKE2 노드의 hostPort 443 바인딩)
resource "ncloud_lb_target_group" "web_https_tg" {
  vpc_no      = ncloud_vpc.vpc.id
  protocol    = "TCP"
  target_type = "VSVR"
  port        = 443
  name        = "team1-web-https-tg"

  health_check {
    protocol       = "TCP"
    port           = 443
    cycle          = 30
    up_threshold   = 2
    down_threshold = 2
  }
}

# Web HTTP 리스너 (Port 80)
resource "ncloud_lb_listener" "web_http_listener" {
  load_balancer_no = ncloud_lb.web_lb.id
  protocol         = "TCP"
  port             = 80
  target_group_no  = ncloud_lb_target_group.web_http_tg.id
}

# Web HTTPS 리스너 (Port 443)
resource "ncloud_lb_listener" "web_https_listener" {
  load_balancer_no = ncloud_lb.web_lb.id
  protocol         = "TCP"
  port             = 443
  target_group_no  = ncloud_lb_target_group.web_https_tg.id
}
