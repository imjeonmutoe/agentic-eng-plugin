# agentic-eng-plugin

에이전틱 엔지니어링 팀 Claude Code 플러그인. 이 repo 하나가 **마켓플레이스와 플러그인을 함께** 담는다.

```
.claude-plugin/marketplace.json   마켓플레이스 매니페스트 (name: agentic-eng)
agentic-eng-toolkit/              플러그인 본체 (name: agentic-eng-toolkit)
```

## 설치

```bash
/plugin marketplace add imjeonmutoe/agentic-eng-plugin
/plugin install agentic-eng-toolkit@agentic-eng
```

팀 전체에 적용하려면 프로젝트의 `.claude/settings.json`에 넣는다. 레포를 클론한 사람은 자동으로 같은 구성을 받는다.

```json
{
  "extraKnownMarketplaces": {
    "agentic-eng": {
      "source": { "source": "github", "repo": "imjeonmutoe/agentic-eng-plugin" }
    }
  },
  "enabledPlugins": {
    "agentic-eng-toolkit@agentic-eng": true
  }
}
```

## 담긴 것

| 종류 | 이름 | 하는 일 |
|---|---|---|
| 스킬+커맨드 | `ai-readiness-cartography` | 레포를 7카테고리 100점 루브릭으로 감사 → HTML 대시보드 + ROI 액션 |
| 스킬+커맨드 | `wiki-ingest` | `raw/`의 새 소스를 읽어 위키에 통합 |
| 스킬+커맨드 | `wiki-query` | 축적된 위키로 답하고 synthesis로 되돌림 |
| 스킬+커맨드 | `wiki-lint` | 상충·고아 페이지·깨진 링크·지식 공백 점검 |
| 훅 | `PreToolUse[Edit\|Write]` | TDD 가드 — 테스트 없는 TS/JS 구현 파일 작성을 차단 |

자세한 내용은 [`agentic-eng-toolkit/README.md`](agentic-eng-toolkit/README.md).

## 마켓플레이스에 플러그인 추가하기

`.claude-plugin/marketplace.json`의 `plugins` 배열에 항목을 더한다. 같은 repo 안에 두면
`"source": "./디렉터리이름"` 으로 참조한다. 다른 repo의 플러그인은 `git-subdir` + HTTPS URL을 쓴다
(`github` source는 SSH로 클론해서 설치하는 사람마다 키 등록이 필요하다).

push 전에 로컬에서 검증한다.

```bash
claude plugin validate .
```

## 테스트

TDD 가드의 허용/차단 규칙은 전부 glob 패턴이라, 하나를 넓히면 테스트 없는 구현 파일이
조용히 통과한다 — 차단 로그가 남지 않아 눈치채기 어렵다. 회귀 테스트가 그 종류를 잡는다.

```bash
bash tests/tdd-guard.test.sh
```

임시 디렉터리에 픽스처 레포를 만들어 훅 입력 JSON 을 직접 먹이고 allow/deny 판정을 검증한다.
`jq` 외에 의존성은 없고, 모든 push 와 PR 에서 CI 로도 돌아간다.
