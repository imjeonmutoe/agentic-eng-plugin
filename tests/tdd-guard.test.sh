#!/usr/bin/env bash
# TDD 가드 회귀 테스트.
#
# 가드의 허용/차단 규칙은 전부 glob 패턴이라, 패턴 하나를 넓히면 테스트 없는 구현 파일이
# 조용히 통과한다 — 차단 로그가 남지 않으니 아무도 눈치채지 못한다. 실제로 `*test*`,
# `*.config.*` 같은 부분매칭 때문에 latestPrice.ts, tailwindUtils.ts 가 뚫려 있었다.
# 그 종류의 재발을 잡는 것이 이 테스트의 목적이다.
#
# 실행: bash tests/tdd-guard.test.sh   (jq 필요)

set -u

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GUARD="$REPO_ROOT/agentic-eng-toolkit/scripts/tdd-guard.sh"

if [ ! -x "$GUARD" ]; then
  echo "가드 스크립트를 찾을 수 없거나 실행 권한이 없다: $GUARD" >&2
  exit 1
fi
command -v jq >/dev/null || { echo "jq 가 필요하다." >&2; exit 1; }

PASS=0
FAIL=0

# 픽스처는 git 저장소로 만든다. 가드가 `git rev-parse --show-toplevel` 로 루트를 찾아
# package.json 존재 여부를 보기 때문에, git init 을 해두면 TMPDIR 위치와 무관하게
# 루트가 픽스처 자신으로 고정된다. (init 하지 않으면 상위 저장소 루트가 잡힐 수 있고,
# 그 경우 package.json 이 없어 가드가 전부 통과시켜 테스트가 무의미해진다.)
FIXTURE=$(mktemp -d)
BOOTSTRAP=$(mktemp -d)
trap 'rm -rf "$FIXTURE" "$BOOTSTRAP"' EXIT

setup_fixture() {
  cd "$FIXTURE" || exit 1
  git init -q . 2>/dev/null
  printf '{"name":"fixture","private":true}' > package.json

  mkdir -p lib/__tests__ src/__tests__ src/deep app types .claude/hooks workflows tests/e2e test/helpers

  # 짝이 되는 테스트가 있는 구현 — 통과해야 한다
  : > lib/cart.ts;             : > lib/cart.test.ts
  : > lib/coupon.ts;           : > lib/__tests__/coupon.test.ts
  : > lib/legacy.js;           : > lib/legacy.spec.js
  : > src/deep/widget.ts;      : > src/__tests__/widget.test.ts

  # 차단 대상은 파일을 만들지 않는다 — Write 로 새 파일을 만드는 상황을 그대로 재현한다.
}

setup_bootstrap() {
  cd "$BOOTSTRAP" || exit 1
  git init -q . 2>/dev/null
  # package.json 을 일부러 만들지 않는다.
}

# 가드는 허용할 때 아무것도 출력하지 않고 exit 0 한다. 빈 출력을 allow 로 해석한다
# (빈 입력을 jq 에 넘기면 `// "allow"` 폴백이 동작하지 않고 빈 문자열이 나온다).
verdict() {
  local out
  out=$(printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$GUARD")
  if [ -z "$out" ]; then
    echo allow
  else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
  fi
}

expect() { # $1=상대경로  $2=allow|deny  $3=설명
  local base="${4:-$FIXTURE}" got
  got=$(verdict "$base/$1")
  if [ "$got" = "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %-30s 기대=%-5s 실제=%-5s  %s\n' "$1" "$2" "$got" "$3"
  fi
}

expect_bootstrap() { expect "$1" "$2" "$3" "$BOOTSTRAP"; }

group() { printf '\n%s\n' "$1"; }

setup_fixture

group "부분매칭 오탐 — 테스트가 없으므로 차단되어야 한다"
# 아래 이름들은 각각 test/spec/config/env/tailwind/postcss/tsconfig 를 부분 문자열로
# 포함한다. 허용 패턴을 다시 넓히면 여기서 걸린다.
expect lib/latestPrice.ts       deny "la(test)Price"
expect lib/greatest.ts          deny "grea(test)"
expect lib/contest.ts           deny "con(test)"
expect lib/inspector.ts         deny "in(spec)tor"
expect lib/specialOffer.ts      deny "(spec)ialOffer"
expect lib/app.config.helper.ts deny "app(.config.)helper"
expect lib/parse.environment.ts deny "parse(.env)ironment"
expect lib/tailwindUtils.ts     deny "(tailwind)Utils"
expect lib/postcssPlugin.ts     deny "(postcss)Plugin"
expect lib/tsconfigLoader.ts    deny "(tsconfig)Loader"

group "기본 동작 — 테스트 없는 구현은 차단"
expect lib/payment.ts           deny "일반 구현"
expect src/services/order.ts    deny "중첩 경로"
expect components/Button.tsx    deny "tsx 구현"
expect lib/helper.js            deny "js 구현"
expect lib/panel.jsx            deny "jsx 구현"

group "짝이 되는 테스트가 있으면 통과"
expect lib/cart.ts              allow "같은 폴더 .test.ts"
expect lib/coupon.ts            allow "lib/__tests__/"
expect lib/legacy.js            allow "같은 폴더 .spec.js"
expect src/deep/widget.ts       allow "src/__tests__/ 루트 폴더"
# src/__tests__/ 폴백은 basename 만 보고 레포 전역에서 찾는다. 즉 src/__tests__/widget.test.ts
# 하나가 경로와 무관하게 모든 widget.* 를 허용한다. 의도된 느슨함이므로 동작을 고정해 둔다 —
# 좁히려면 이 케이스가 먼저 깨진다.
expect lib/widget.jsx           allow "basename 전역 매칭(느슨함, 의도됨)"

group "테스트 파일 자체는 통과"
expect lib/cart.test.ts             allow "*.test.*"
expect lib/order.spec.ts            allow "*.spec.*"
expect lib/__tests__/coupon.test.ts allow "__tests__/"
expect tests/e2e/checkout.ts        allow "tests/ 디렉터리"
expect test/helpers/setup.ts        allow "test/ 디렉터리"

group "설정 파일은 통과 — *tailwind* 등 부분매칭 패턴을 제거한 데 대한 회귀 검사"
expect tailwind.config.ts       allow ""
expect tailwind.config.js       allow ""
expect postcss.config.mjs       allow ""
expect postcss.config.cjs       allow ""
expect next.config.ts           allow ""
expect next.config.mjs          allow ""
expect vite.config.ts           allow ""
expect jest.config.js           allow ""
expect tsconfig.json            allow ""
expect .env                     allow ""
expect .env.local               allow ""

group "types / Next.js 프레임워크 / 인프라 경로는 통과"
expect types/order.ts           allow "types/ 폴더"
expect lib/types.ts             allow "types.ts"
expect app/page.tsx             allow ""
expect app/layout.tsx           allow ""
expect app/loading.tsx          allow ""
expect app/error.tsx            allow ""
expect app/not-found.tsx        allow ""
expect .claude/hooks/custom.ts  allow ".claude/ 인프라"
expect workflows/deploy.ts      allow "workflows/ 오케스트레이션"

group "부트스트랩 — package.json 이 없으면 가드가 동작하지 않는다"
setup_bootstrap
expect_bootstrap lib/payment.ts  allow "스캐폴딩 전에는 막지 않는다"
expect_bootstrap lib/anything.ts allow "스캐폴딩 전에는 막지 않는다"

group "훅 출력 계약 — 차단 시 Claude Code 가 읽을 수 있는 JSON 이어야 한다"
cd "$FIXTURE" || exit 1
DENY_JSON=$(printf '{"tool_input":{"file_path":"%s"}}' "$FIXTURE/lib/payment.ts" | bash "$GUARD")
contract() { # $1=jq 표현식  $2=기대값  $3=설명
  local got
  got=$(printf '%s' "$DENY_JSON" | jq -r "$1" 2>/dev/null)
  if [ "$got" = "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %-30s 기대=%-5s 실제=%-5s\n' "$3" "$2" "$got"
  fi
}
printf '%s' "$DENY_JSON" | jq -e . >/dev/null 2>&1 \
  && PASS=$((PASS + 1)) \
  || { FAIL=$((FAIL + 1)); printf '  FAIL  차단 출력이 올바른 JSON 이 아니다\n'; }
contract '.hookSpecificOutput.hookEventName'      PreToolUse "hookEventName"
contract '.hookSpecificOutput.permissionDecision' deny       "permissionDecision"
if printf '%s' "$DENY_JSON" | jq -e '.hookSpecificOutput.permissionDecisionReason | length > 0' >/dev/null 2>&1; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); printf '  FAIL  차단 사유 문자열이 비어 있다\n'
fi

printf '\n----\n'
if [ "$FAIL" -eq 0 ]; then
  printf '전체 통과 — %d건\n' "$PASS"
  exit 0
else
  printf '실패 %d건 / 전체 %d건\n' "$FAIL" "$((PASS + FAIL))"
  exit 1
fi
