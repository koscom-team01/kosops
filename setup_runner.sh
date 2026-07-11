#!/bin/bash
set -e

# Configuration
GITHUB_ORG="koscom-team01"

echo "======================================================================"
echo "      KOSOPS GitHub Actions Self-Hosted Runner Auto-Setup Tool"
echo "======================================================================"

# Check if GITHUB_PAT is provided
if [ -z "$GITHUB_PAT" ]; then
    echo -e "\033[31m[ERROR] GITHUB_PAT 환경변수가 설정되지 않았습니다.\033[0m"
    echo -e "깃허브에서 발급한 개인 보안 토큰(PAT)을 환경변수로 등록한 뒤 실행해 주세요."
    echo -e "실행 예시:"
    echo -e "  export GITHUB_PAT='github_pat_your_token_here'"
    echo -e "  $0"
    exit 1
fi

# Ensure kubeconfig is exported
if [ -z "$KUBECONFIG" ]; then
    # Default to local kubeconfig if present
    if [ -f "team1-kubeconfig.yaml" ]; then
        export KUBECONFIG="$(pwd)/team1-kubeconfig.yaml"
        echo -e "\033[32m[INFO] 로컬 kubeconfig 파일 발견 및 적용: $KUBECONFIG\033[0m"
    else
        echo -e "\033[33m[WARNING] KUBECONFIG 환경변수가 설정되어 있지 않고 로컬 파일도 찾을 수 없습니다.\033[0m"
        echo -e "현재 kubectl 연결 상태를 기준으로 진행합니다."
    fi
fi

echo -e "\n\033[32m[Step 1] GitHub API를 통해 조직 공용 러너 등록 토큰 조회 중...\033[0m"
# GitHub API 호출하여 Organization용 러너 등록 토큰 가져오기
RESPONSE=$(curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_PAT" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token")

# JSON 파싱하여 토큰만 추출
RUNNER_TOKEN=$(echo "$RESPONSE" | grep -o '"token": "[^"]*' | grep -o '[^"]*$')

if [ -z "$RUNNER_TOKEN" ]; then
    echo -e "\033[31m[ERROR] GitHub API로부터 러너 토큰을 가져오지 못했습니다.\033[0m"
    echo -e "토큰 권한(org admin/read) 또는 조직명(${GITHUB_ORG})을 확인해 주세요."
    echo -e "API 응답: $RESPONSE"
    exit 1
fi

echo -e "\033[32m[OK] 러너 등록 토큰 조회 완료.\033[0m"

echo -e "\n\033[32m[Step 2] 쿠버네티스 네임스페이스 및 Secret 생성 중...\033[0m"
# 네임스페이스 생성
kubectl create namespace github-runner --dry-run=client -o yaml | kubectl apply -f -

# 토큰을 안전하게 Secret으로 주입
kubectl create secret generic github-runner-secret \
  -n github-runner \
  --from-literal=runner-token="${RUNNER_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "\033[32m[OK] github-runner-secret 생성이 완료되었습니다.\033[0m"
echo -e "\n======================================================================"
echo -e "\033[32m🎉 설정 완료! ArgoCD가 자동으로 Runner Pod를 배포하고 깃허브에 연결합니다.\033[0m"
echo -e "======================================================================"
