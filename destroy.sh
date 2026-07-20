#!/bin/bash
set -e

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

echo -e "${YELLOW}======================================================================${NC}"
echo -e "${RED}             [WARNING] KOSOPS 인프라 완전 삭제 스크립트${NC}"
echo -e "${YELLOW}======================================================================${NC}"

# 1. 인자 처리 및 입력 자동화 (명령어 인자 -> 환경 변수 순으로 탐색)
ACCESS_KEY="${1:-$NCP_ACCESS_KEY}"
SECRET_KEY="${2:-$NCP_SECRET_KEY}"

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

# Naver Cloud 플랫폼 선택 (Public vs Financial)
echo -e "\n${YELLOW}삭제할 인프라가 구축된 Naver Cloud Platform 환경을 선택하세요:${NC}"
echo -e "  1) Public Cloud (기본값)"
echo -e "  2) Financial (금융) Cloud"
echo -n "선택 (1 또는 2): "
read -r CLOUD_CHOICE

if [ "$CLOUD_CHOICE" = "2" ]; then
    echo -e "${GREEN}[INFO] Naver Financial Cloud 환경의 자원을 삭제합니다.${NC}"
    NCLOUD_SITE="fin"
    NCLOUD_REGION="FKR"
    ZONE_KR1="FKR-1"
    ZONE_KR2="FKR-2"
else
    echo -e "${GREEN}[INFO] Naver Public Cloud 환경의 자원을 삭제합니다.${NC}"
    NCLOUD_SITE="public"
    NCLOUD_REGION="KR"
    ZONE_KR1="KR-1"
    ZONE_KR2="KR-2"
fi

# 2. Kubernetes 리소스 정리 (과금 유발하는 로드밸런서 및 블록 스토리지 우선 삭제)
LOCAL_KUBECONFIG="team1-kubeconfig.yaml"
if [ -f "$LOCAL_KUBECONFIG" ]; then
    echo -e "\n${GREEN}[Step 1] Kubernetes 리소스 (서비스 및 PVC) 정리 중...${NC}"
    export KUBECONFIG="$(pwd)/$LOCAL_KUBECONFIG"
    
    # ArgoCD 루트 앱 삭제를 통한 하위 애플리케이션 및 인프라 자원 연쇄 정리
    if kubectl get application root-app -n argocd &>/dev/null; then
        echo -e "ArgoCD root-app 삭제 중..."
        kubectl delete -f gitops/bootstrap/root-app.yaml --timeout=90s || true
    fi
    
    # 네임스페이스 삭제로 하위 자원 정리 유도
    echo -e "네임스페이스 삭제 중 (harbor, github-runner, test-web)..."
    kubectl delete namespace harbor test-web github-runner --timeout=120s || true
    
    # 잔여 PV/PVC 및 LoadBalancer 서비스 강제 삭제
    echo -e "잔여 LoadBalancer 서비스 및 PVC 강제 정리..."
    kubectl delete svc -A --field-selector type=LoadBalancer || true
    kubectl delete pvc -A --all --timeout=60s || true
fi

# 3. Terraform Destroy 실행
echo -e "\n${GREEN}[Step 2] Naver Cloud 인프라 자원 삭제 (Terraform Destroy)...${NC}"
if [ -d "terraform/envs/koscom-team01" ]; then
    cd terraform/envs/koscom-team01
    
    # Terraform destroy 실행 (Access/Secret Key 및 리전 변수 입력 바인딩)
    terraform destroy -auto-approve \
      -var="ncloud_access_key=${ACCESS_KEY}" \
      -var="ncloud_secret_key=${SECRET_KEY}" \
      -var="ncloud_site=${NCLOUD_SITE}" \
      -var="ncloud_region=${NCLOUD_REGION}" \
      -var="zone_kr1=${ZONE_KR1}" \
      -var="zone_kr2=${ZONE_KR2}"
    
    cd ../../../
else
    echo -e "${RED}[ERROR] terraform/envs/koscom-team01 디렉토리를 찾을 수 없습니다.${NC}"
    exit 1
fi

# 4. 로컬 잔여 파일 정리
echo -e "\n${GREEN}[Step 3] 로컬 환경설정 파일 정리...${NC}"
rm -f "$LOCAL_KUBECONFIG"
rm -f "team1-kosops-key.pem"
echo -e "${GREEN}[OK] 로컬 설정 파일 정리 완료.${NC}"

echo -e "\n${YELLOW}======================================================================${NC}"
echo -e "${GREEN}🎉 모든 NCP 인프라 및 로컬 자원이 안전하게 삭제되었습니다! (과금 방지 완료)${NC}"
echo -e "${YELLOW}======================================================================${NC}"
