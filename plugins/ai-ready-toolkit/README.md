# AI-Ready Toolkit

Claude Code 플러그인. 팀이 코딩 에이전트와 일하기 위한 두 축을 담았다.

| 축 | 스킬 | 하는 일 |
|---|---|---|
| 레포 진단 | `ai-readiness-cartography` | 레포를 7카테고리 100점 루브릭으로 감사해 HTML 대시보드 + ROI 순 액션 리스트를 낸다 |
| 지식 축적 | `wiki-ingest` | `raw/`의 새 소스를 읽고 위키에 녹여 넣는다 |
| | `wiki-query` | 축적된 위키로 질문에 답하고, 남길 값어치가 있으면 synthesis 페이지로 되돌린다 |
| | `wiki-lint` | 상충·고아 페이지·깨진 링크·지식 공백을 찾아 리포트한다 |

## 설치

이 디렉터리가 **플러그인 본체**다. 마켓플레이스 매니페스트는 별도 repo(`signal-team-marketplace`)에 있고,
그쪽에서 이 경로(`plugins/ai-ready-toolkit`)를 `git-subdir` source로 가져간다.

```bash
/plugin marketplace add imjeonmutoe/signal-team-marketplace
/plugin install ai-ready-toolkit@signal-team-marketplace
```

팀 전체에 적용하려면 프로젝트의 `.claude/settings.json`에 넣는다. 레포를 클론한 사람은 자동으로 같은 구성을 받는다.

```json
{
  "extraKnownMarketplaces": {
    "signal-team-marketplace": {
      "source": { "source": "github", "repo": "imjeonmutoe/signal-team-marketplace" }
    }
  },
  "enabledPlugins": {
    "ai-ready-toolkit@signal-team-marketplace": true
  }
}
```

## 사용

**슬래시 커맨드** — 명시적 호출. 인자를 받는다.

```
/ai-ready-toolkit:ai-readiness [레포 경로]
/ai-ready-toolkit:ingest       [raw 파일]
/ai-ready-toolkit:query        [질문]
/ai-ready-toolkit:lint         [범위]
```

**스킬** — 평문으로 말하면 description이 매칭돼 자동으로 걸린다.

```
"이 레포 agent-friendly 한지 점수 매겨줘"   → ai-readiness-cartography
"raw에 새 글 넣었어"                        → wiki-ingest
"위키에서 X랑 Y 차이 찾아줘"                 → wiki-query
"위키 상태 어때"                            → wiki-lint
```

커맨드 이름을 스킬 이름과 다르게 둔 것은 의도적이다. 같으면 `claude plugin details`에서
같은 이름이 두 번 잡혀 어느 쪽이 불릴지 모호해진다.

## ai-readiness-cartography

레포 경로 하나만 있으면 동작한다. 사전 준비 없음.

산출물 3종 — 점수 JSON, 단일 HTML 대시보드, ROI 순 액션 리스트.
저장 위치는 `docs/` → `.claude/` → 레포 루트 순으로 자동 선택된다.

채점은 `scripts/score.py`(Python 3.10+, stdlib only)가 자동으로 하고, 스크립트가 잡지
못하는 정성 항목만 Claude가 보강한다. 자동 항목 중 핵심은 **E1 hallucinated path 검증** —
컨텍스트 문서가 언급하는 경로가 실제로 존재하는지 전수 확인한다.

등급: 90+ AI-Native · 75+ AI-Ready · 60+ AI-Assisted · 40+ AI-Fragile · 그 아래 AI-Hostile

## wiki 3종 — 볼트 구조가 필요하다

위키 스킬들은 아래 구조를 전제한다. **빈 레포에 설치하면 동작하지 않는다.**
새로 시작한다면 이 구조를 먼저 만든다.

```
raw/                 사용자가 넣는 원본 마크다운 (읽기 전용 — 스킬이 절대 수정하지 않는다)
wiki/
  index.md           카테고리별 카탈로그. 질의는 항상 여기서 시작
  log.md             시간순 append-only 기록
  sources/           소스 1건 = 요약 페이지 1개
  concepts/          개념·원칙·기법
  entities/          도구·라이브러리·인물·회사
  synthesis/         질문에 대한 답 중 남길 값어치가 있는 것
```

`CLAUDE.md`에는 최소한 **학습 주제 한 줄**이 있어야 한다. `wiki-ingest`는 주제가 비어 있으면
사용자에게 먼저 묻는다.

모든 위키 페이지는 아래 frontmatter를 가진다.

```yaml
---
type: source | concept | entity | synthesis
title: 사람이 읽는 제목
aliases: []
tags: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: []            # 근거가 된 raw 파일 또는 source 페이지
confidence: high | medium | low
---
```

핵심 규약 셋:

- 파일명은 **볼트 전체에서 유일**해야 한다. `[[위키링크]]`가 이름으로 걸리기 때문.
- 새 소스가 기존 주장과 충돌하면 **덮어쓰지 않는다.** `> ⚠️ **상충**` 블록으로 양쪽을 남긴다.
- 소스에 없는 일반 지식을 보탤 때는 `> 💭 **배경지식:**`으로 표시한다.

## 라이선스

MIT
