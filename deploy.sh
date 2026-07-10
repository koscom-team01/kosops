#!/bin/bash

# ==============================================================================
# kosops (koscom-team01) 원클릭 인프라 프로비저닝 및 RKE2/GitOps 자동 배포 스크립트
# ==============================================================================

set -e

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${GREEN}    _  __ ___   ____   ___   ____  ____  ${NC}"
echo -e "${GREEN}   | |/ // _ \ / ___| / _ \ |  _ \/ ___| ${NC}"
echo -e "${GREEN}   | ' /| | | |\___ \| | | || |_) \___ \ ${NC}"
echo -e "${GREEN}   | . \| |_| | ___) | |_| ||  __/ ___) |${NC}"
echo -e "${GREEN}   |_|\_\\\___/ |____/ \___/ |_|   |____/ ${NC}"
echo -e "${YELLOW}   KOSCOM New Hire DevOps Project - team1 (kosops)${NC}"
echo -e "${YELLOW}======================================================================${NC}"

# 1. 인자 처리 및 입력 자동화 (명령어 인자 -> 환경 변수 순으로 탐색)
ACCESS_KEY="${1:-$NCP_ACCESS_KEY}"
SECRET_KEY="${2:-$NCP_SECRET_KEY}"
ADMIN_IP="${3:-$NCP_ADMIN_IP}"

# Access Key 입력 확인
if [ -z "$ACCESS_KEY" ]; then
    echo -e "${YELLOW}[INPUT] Naver Cloud Access Key를 입력하세요:${NC}"
    read -r ACCESS_KEY
fi

# Secret Key 입력 확인 (비밀번호 형식으로 숨김 처리)
if [ -z "$SECRET_KEY" ]; then
    echo -e "${YELLOW}[INPUT] Naver Cloud Secret Key를 입력하세요 (입력 시 화면에 보이지 않음):${NC}"
    read -rs SECRET_KEY
    echo ""
fi

# 개발자 공인 IP 자동 감지
if [ -z "$ADMIN_IP" ]; then
    echo -e "${GREEN}[INFO] 개발자 공인 IP를 자동으로 감지하는 중...${NC}"
    DETECTED_IP=$(curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://api.ipify.org || echo "")
    if [ -n "$DETECTED_IP" ]; then
        ADMIN_IP="${DETECTED_IP}/32"
        echo -e "${GREEN}[INFO] 공인 IP가 자동으로 감지되었습니다: ${ADMIN_IP}${NC}"
    else
        echo -e "${RED}[WARNING] 공인 IP 자동 감지에 실패했습니다.${NC}"
        echo -e "${YELLOW}[INPUT] 본인의 공인 IP 대역을 입력하세요 (예: 211.233.1.2/32):${NC}"
        read -r ADMIN_IP
    fi
else
    # 인자로 넘어온 IP에 서픽스(/32)가 없으면 자동으로 붙여줌
    if [[ ! "$ADMIN_IP" =~ "/" ]]; then
        ADMIN_IP="${ADMIN_IP}/32"
    fi
fi

# 2. Terraform을 통한 NCP 리소스 생성
echo -e "\n${GREEN}[Step 1] Naver Cloud VPC 및 RKE2 인프라 생성 (Terraform)...${NC}"
cd terraform/envs/koscom-team01

terraform init

echo -e "${GREEN}[INFO] Terraform Apply 시작...${NC}"
terraform apply -auto-approve \
  -var="ncloud_access_key=${ACCESS_KEY}" \
  -var="ncloud_secret_key=${SECRET_KEY}" \
  -var="admin_ip=${ADMIN_IP}"

# Output 정보 파싱
BASTION_IP=$(terraform output -raw bastion_public_ip)
CP_PRIVATE_IP=$(terraform output -raw rke2_cp_private_ip)
API_LB_DOMAIN=$(terraform output -raw api_lb_domain)

cd ../../..

# pem 개인키 권한 축소 (SSH 보안 규칙 충족)
PEM_FILE="team1-kosops-key.pem"
if [ -f "$PEM_FILE" ]; then
    chmod 600 "$PEM_FILE"
    echo -e "${GREEN}[INFO] SSH 개인키 권한 변경 완료 (chmod 600 ${PEM_FILE})${NC}"
else
    echo -e "${RED}[WARNING] 개인키 파일(${PEM_FILE})이 아직 생성되지 않았습니다. 인프라 생성 확인이 필요합니다.${NC}"
fi

# 3. RKE2 CP 서버 부트스트랩 대기 (user_data 수행 모니터링)
echo -e "\n${GREEN}[Step 2] RKE2 Control Plane VM 및 서비스 기동 대기 (약 1.5~2분 소요)...${NC}"
echo -e "Bastion IP: ${BASTION_IP}"
echo -e "CP Private IP: ${CP_PRIVATE_IP}"
echo -e "API LB Domain: ${API_LB_DOMAIN}"

MAX_ATTEMPTS=25
ATTEMPT=1
KUBECONFIG_READY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo -e "RKE2 상태 점검 중... ($ATTEMPT/$MAX_ATTEMPTS)"
    
    # Bastion 터널링을 통해 CP Node 내부의 rke2.yaml 파일 생성 여부 체크
    if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
        -o ProxyCommand="ssh -i $PEM_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ncloud@$BASTION_IP" \
        ncloud@$CP_PRIVATE_IP "sudo test -f /etc/rancher/rke2/rke2.yaml" 2>/dev/null; then
        
        # 파일 권한 확인 및 읽기 가능 검증
        if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ProxyCommand="ssh -i $PEM_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ncloud@$BASTION_IP" \
            ncloud@$CP_PRIVATE_IP "sudo chmod 644 /etc/rancher/rke2/rke2.yaml" 2>/dev/null; then
            
            KUBECONFIG_READY=true
            break
        fi
    fi
    
    sleep 15
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$KUBECONFIG_READY" = false ]; then
    echo -e "${RED}[ERROR] RKE2 클러스터 생성 대기 시간이 초과되었습니다.${NC}"
    echo -e "Bastion Host(${BASTION_IP}) 또는 CP Node(${CP_PRIVATE_IP})에 SSH로 접속하여 /var/log/cloud-init-output.log 로그를 확인하세요."
    exit 1
fi

echo -e "${GREEN}[OK] RKE2 Control Plane 서버 준비 완료!${NC}"

# 4. Kubeconfig 로컬 다운로드 및 Endpoint 패치
echo -e "\n${GREEN}[Step 3] Kubeconfig 파일 로컬 다운로드 및 Load Balancer Endpoint 적용...${NC}"
LOCAL_KUBECONFIG="team1-kubeconfig.yaml"

# Bastion 경유하여 rke2.yaml을 로컬로 가져옴
ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ProxyCommand="ssh -i $PEM_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ncloud@$BASTION_IP" \
    ncloud@$CP_PRIVATE_IP "cat /etc/rancher/rke2/rke2.yaml" > "$LOCAL_KUBECONFIG"

# 로컬 kubeconfig의 server 주소를 Localhost -> NCP Network Load Balancer Domain으로 변경
sed -i.bak "s/127.0.0.1/$API_LB_DOMAIN/g" "$LOCAL_KUBECONFIG"
rm -f "${LOCAL_KUBECONFIG}.bak"

export KUBECONFIG="$(pwd)/$LOCAL_KUBECONFIG"
echo -e "${GREEN}[OK] Kubeconfig가 '${LOCAL_KUBECONFIG}' 파일로 저장 및 패치되었습니다.${NC}"

# kubectl 접속 테스트
echo -e "\n${GREEN}[Step 4] Kubernetes API 서버 접속 및 노드 상태 조회...${NC}"
kubectl get nodes -o wide || {
    echo -e "${RED}[WARNING] API LB 도메인을 통한 직접 kubectl 통신이 실패했습니다.${NC}"
    echo -e "개발자 공인 IP(admin_ip)가 ACG에 정상 등록되었는지 확인하세요."
    echo -e "임시 조치: Bastion 로컬 포트 포워딩을 통해 클러스터에 연결할 수 있습니다."
}

# 5. Helm을 활용한 ArgoCD & Harbor 배포
echo -e "\n${GREEN}[Step 5] Helm을 통한 ArgoCD 및 Harbor Private Registry 배포...${NC}"

if ! command -v helm &> /dev/null; then
    echo -e "${RED}[WARNING] 로컬 머신에 helm 명령어가 없어 자동 플랫폼 배포를 생략합니다.${NC}"
    echo -e "helm을 설치한 후 아래 명령어를 직접 실행해 ArgoCD 및 Harbor를 설치하세요."
    echo -e "--------------------------------------------------------"
    echo -e "export KUBECONFIG=$(pwd)/$LOCAL_KUBECONFIG"
    echo -e "helm repo add argo https://argoproj.github.io/argo-helm"
    echo -e "helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace -f gitops/bootstrap/argocd-values.yaml"
    echo -e "helm repo add harbor https://helm.goharbor.io"
    echo -e "helm upgrade --install harbor harbor/harbor --namespace harbor --create-namespace -f gitops/infrastructure/harbor-values.yaml"
    echo -e "--------------------------------------------------------"
else
    # 4-1. ArgoCD 배포
    echo -e "ArgoCD 배포 중..."
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        -f gitops/bootstrap/argocd-values.yaml

    # 4-2. Harbor 배포
    echo -e "Harbor Private Registry 배포 중..."
    helm repo add harbor https://helm.goharbor.io
    helm repo update
    helm upgrade --install harbor harbor/harbor \
        --namespace harbor \
        --create-namespace \
        -f gitops/infrastructure/harbor-values.yaml

    echo -e "${GREEN}[OK] ArgoCD 및 Harbor Helm 배포 완료!${NC}"
fi

echo -e "\n${YELLOW}======================================================================${NC}"
echo -e "${GREEN}🎉 kosops 클러스터 및 플랫폼 서비스 자동 배포가 완료되었습니다!${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "1. Kubeconfig 경로: ${GREEN}export KUBECONFIG=$(pwd)/$LOCAL_KUBECONFIG${NC}"
echo -e "2. Bastion SSH 접속: ${GREEN}ssh -i $PEM_FILE ncloud@$BASTION_IP${NC}"
echo -e "3. Private Node SSH 접속: ${GREEN}ssh -i $PEM_FILE -o ProxyCommand=\"ssh -i $PEM_FILE -W %h:%p ncloud@$BASTION_IP\" ncloud@$CP_PRIVATE_IP${NC}"
echo -e "4. ArgoCD 호스트 (Nginx Ingress 설정 필요): ${GREEN}https://argocd.hwangonjang.com${NC}"
echo -e "5. Harbor 호스트 (Nginx Ingress 설정 필요): ${GREEN}https://harbor.hwangonjang.com${NC}"
echo -e "${YELLOW}======================================================================${NC}"
