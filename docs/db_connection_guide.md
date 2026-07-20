# [KOS-Chain AI] 개발자용 데이터베이스(DB) 연결 및 개발 가이드

본 문서는 `KOS-Chain AI` 개발에 참여하는 팀원들이 클러스터 내부에 구축된 **PostgreSQL (RDB & VectorDB)** 및 **Neo4j (GraphDB)**에 보안 터널을 뚫어 로컬 개발 환경에서 접속하는 방법과 연동 예제를 다룹니다.

---

## 1. 📌 개요 및 접속 원리

우리 서비스의 데이터베이스는 보안망(VPC Private Subnet) 내부의 쿠버네티스 클러스터 내에 기동되어 있습니다. 
외부 노출로 인한 해킹 및 클라우드 추가 과금을 방지하기 위해, 별도의 공인 IP를 발급받지 않고 **`kubectl port-forward` 터널링 기술**을 사용하여 마치 로컬 컴퓨터(`localhost`)에 DB가 실행 중인 것처럼 연결하여 사용합니다.

```text
[개발자 로컬 PC] ➡️ (보안 터널링: localhost:5432 / 7687) ➡️ [NCP VPC 내부 K8s 클러스터 DB]
```

---

## 2. 🛠️ 사전 준비 (Prerequisites)

데이터베이스 터널링을 개방하기 위해 로컬 PC에 아래 두 가지가 준비되어야 합니다.

### ① kubectl CLI 도구 설치
쿠버네티스 통신을 제어하기 위해 터미널에 `kubectl`이 설치되어 있어야 합니다.
*   **macOS**: `brew install kubernetes-cli`
*   **Windows**: [쿠버네티스 공식 문서](https://kubernetes.io/ko/docs/tasks/tools/install-kubectl-windows/)를 참고하여 다운로드 후 환경변수에 등록

### ② Kubeconfig 접속 키 확보
*   인프라 배포 담당자(또는 사용자)에게 **`team1-kubeconfig.yaml`** 파일을 안전한 채널로 공유받습니다.
*   공유받은 파일을 다운로드하여 **본인의 `kosops` 프로젝트 루트 폴더**에 넣습니다.
*   *(주의: 이 파일은 보안 자격증명이 포함되어 있어 `.gitignore`에 등록되어 있으며, 절대 Git에 커밋해 올리면 안 됩니다.)*

---

## 3. 🔌 원격 터널 개방 방법 (실행)

프로젝트 루트 폴더로 이동한 뒤, 준비된 연결 쉘스크립트를 실행합니다.

```bash
# 1. 스크립트 실행 권한 확인 (필요시 최초 1회 실행)
chmod +x connect_db.sh

# 2. 터널링 스크립트 실행
./connect_db.sh
```

스크립트가 실행되면 아래와 같이 터널링이 개방되고 접속 정보가 표시됩니다. **개발 도중에는 이 터널링 터미널 창을 끄지 않고 유지하셔야 합니다.**

---

## 💾 4. 데이터베이스 세부 접속 정보

터널이 유지되는 동안 아래 정보를 사용해 본인의 로컬 개발 툴(DBeaver, Python 코드 등)에서 접속할 수 있습니다.

### A. PostgreSQL (RDB & VectorDB)
*   **Host**: `localhost` (또는 `127.0.0.1`)
*   **Port**: `5432`
*   **Database**: `koscomdb`
*   **User**: `admin`
*   **Password**: `adminpassword`
*   **💡 Vector DB 최초 활성화 조치**:
    *   로컬 DB 툴(예: DBeaver)을 사용해 PostgreSQL에 최초 접속한 후, 아래 SQL 쿼리를 실행해 주어야 벡터 연산 플러그인이 활성화됩니다:
        ```sql
        CREATE EXTENSION IF NOT EXISTS vector;
        ```

### B. Neo4j (GraphDB)
*   **Bolt URI (코드 연동용)**: `bolt://localhost:7687`
*   **Web Browser UI (시각화 뷰어)**: [http://localhost:7474](http://localhost:7474)
*   **User**: `neo4j`
*   **Password**: `neo4jpassword`

---

## 🐍 5. 파이썬(LangChain) 연동 예제 코드

개발자들의 빠른 코드 연동을 돕기 위해 작성된 **랭체인 기반 데이터베이스 연동 예제**입니다.

### A. PostgreSQL Vector Store 연동 (Vector RAG)
```python
# pip install langchain-postgres langchain-openai
from langchain_postgres.vectorstores import PGVector
from langchain_openai import OpenAIEmbeddings

# 1. OpenAI 임베딩 정의
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

# 2. PostgreSQL 접속 문자열 정의
connection_string = "postgresql+psycopg://admin:adminpassword@localhost:5432/koscomdb"

# 3. 벡터 데이터베이스 로드 및 쿼리
vector_store = PGVector(
    connection_string=connection_string,
    embeddings=embeddings,
    collection_name="news_vectors"
)

# 4. 유사도 검색 수행
results = vector_store.similarity_search("반도체 공급망 리스크 관련 뉴스", k=3)
for doc in results:
    print(doc.page_content)
```

### B. Neo4j Graph Database 연동 (Graph-RAG / Cypher Query)
```python
# pip install langchain-community neo4j
from langchain_community.graphs import Neo4jGraph

# 1. Neo4j 그래프 데이터베이스 인스턴스 연결
graph = Neo4jGraph(
    url="bolt://localhost:7687",
    username="neo4j",
    password="neo4jpassword"
)

# 2. 기업 연관 관계 Cypher 쿼리 조회 테스트
query = """
MATCH (c1:Company {name: '한미반도체'})-[r:SUPPLIES_TO]->(c2:Company)
RETURN c1.name, r.product, c2.name
"""
result = graph.query(query)
print("관계망 결과:", result)
```

---

## 🚪 5. 접속 종료
개발 작업을 모두 마쳤다면, 스크립트를 실행했던 터미널 창으로 돌아와 **`[Enter]`** 키를 누르시면 백그라운드로 실행 중이던 모든 포트포워딩 터널이 안전하게 일괄 자동 종료됩니다.
