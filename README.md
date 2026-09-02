# ai-ready-toolkit

Claude Code 플러그인 저장소. 플러그인 본체는 [`plugins/ai-ready-toolkit/`](plugins/ai-ready-toolkit/)에 있다.

```bash
/plugin marketplace add imjeonmutoe/signal-team-marketplace
/plugin install ai-ready-toolkit@signal-team-marketplace
```

## 왜 하위 디렉터리인가

마켓플레이스가 다른 repo의 플러그인을 HTTPS로 가져오려면 `git-subdir` source를 써야 하고,
이 source는 **비어 있지 않은 하위 경로**를 요구한다. 루트에 두면 지정할 방법이 없다.

대안인 `github` source는 SSH(`git@github.com:`)로 클론하므로 설치하는 사람마다
GitHub SSH 키가 등록돼 있어야 한다. 팀 배포에는 맞지 않아 채택하지 않았다.
