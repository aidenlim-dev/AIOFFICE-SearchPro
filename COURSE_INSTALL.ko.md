# 강의 수강생 설치 가이드

## 1. 설치

Claude Code 안에서 실행합니다.

```bash
/plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
/plugin install aioffice-searchpro@aioffice-searchpro-marketplace
/reload-plugins
```

AI 에이전트(Claude Code 자신 포함)에게 설치를 시키는 경우, 위 슬래시 명령은 대화형 UI 전용이라 에이전트가 실행할 수 없습니다. 대신 터미널에서 비대화형 CLI를 실행하게 하세요:

```bash
claude plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
claude plugin install aioffice-searchpro@aioffice-searchpro-marketplace
```

설치 후 Claude Code를 재시작하거나 `/reload-plugins`를 실행하면 플러그인이 로드됩니다.

Codex를 쓴다면 같은 저장소로 이렇게 설치합니다:

```bash
codex plugin marketplace add https://github.com/aidenlim-dev/AIOFFICE-SearchPro
codex plugin add aioffice-searchpro@aioffice-searchpro-marketplace
```

## 2. 간단 테스트

Claude Code에게 이렇게 물어봅니다.

```text
https://example.com/ 읽어줘
```

막힌 사이트를 테스트할 때는 공개 페이지 URL만 사용하세요. 로그인, 페이월, 비공개 데이터는 대상이 아닙니다.

## 3. 상태 점검

이미 마켓플레이스로 설치했다면 **클론 없이** 설치된 복사본에서 바로 실행합니다.

```bash
bash ~/.claude/plugins/marketplaces/aioffice-searchpro-marketplace/setup/doctor.sh
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\plugins\marketplaces\aioffice-searchpro-marketplace\setup\doctor.ps1"
```

아직 설치 전이거나 저장소에서 직접 점검하려면:

```bash
git clone https://github.com/aidenlim-dev/AIOFFICE-SearchPro.git
cd AIOFFICE-SearchPro
bash setup/doctor.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/aidenlim-dev/AIOFFICE-SearchPro.git
cd AIOFFICE-SearchPro
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\doctor.ps1
```

doctor 끝의 `=== doctor summary ===`가 결과를 요약해 줍니다: `CORE: ready`면 바로 사용 가능하고, OPTIONAL(브라우저 폴백)은 Cloudflare급 사이트에서만 필요한 선택 사항입니다. AI 에이전트에게 시킨 경우, OPTIONAL 항목은 보고만 받고 원할 때만 설치를 진행하게 하세요.

`warn`은 선택 기능 경고입니다. 기본 fetch가 되는지 보려면 `engine smoke test passed`를 확인하세요.

공개 라우트 라이브 체크:

```bash
bash setup/live-check.sh
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\live-check.ps1
```

조금 더 넓게 확인하고 싶을 때:

```bash
AIOFFICE_SEARCHPRO_LIVE_EXTENDED=1 bash setup/live-check.sh
```

Windows PowerShell:

```powershell
$env:AIOFFICE_SEARCHPRO_LIVE_EXTENDED="1"
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\live-check.ps1
```

원문 HTML을 파싱해야 하는 과제에서는 성공한 같은 호출에서 바로 저장하세요. `--json`은 본문을 JSON에 넣지 않으므로, 본문을 얻으려고 같은 URL을 다시 호출하면 WAF 사이트에서 성공 기회를 놓칠 수 있습니다.

```bash
bash setup/run-engine.sh "https://example.com/" --json --output page.html --metadata page.fetch.json
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\run-engine.ps1 "https://example.com/" --json --output page.html --metadata page.fetch.json
```

## 4. 브라우저 폴백까지 켜기

Cloudflare급 JS 렌더링, Akamai/DataDome류 강한 WAF 대응력을 높이고 싶을 때만 실행합니다.

```bash
bash setup/browser.sh
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup\browser.ps1
```

끝난 뒤 Claude Code를 재시작하거나 `/reload-plugins`를 실행하세요.

## 5. 자주 나는 문제

- `Claude Code CLI not found`: Claude Code를 먼저 설치하세요.
- `python3 is required`: Python 3가 필요합니다.
- `Node.js not found`: 기본 사용은 가능하지만 local Chrome fallback은 동작하지 않습니다. macOS/Linux는 `setup/browser.sh`, Windows는 `setup/browser.ps1`를 쓰려면 Node를 설치하세요.
- `Playwright MCP not configured`: 기본 사용은 가능하지만 JS 렌더링 정찰이 제한됩니다. macOS/Linux는 `setup/browser.sh`, Windows는 `setup/browser.ps1`을 실행하세요.
- `auth_required`, `paywall`, `not_found`: 플러그인이 우회하지 않는 정상 중단입니다.

## 6. 설치 명령 다시

```bash
/plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
/plugin install aioffice-searchpro@aioffice-searchpro-marketplace
/reload-plugins
```

AI 에이전트에게 시킬 때 (터미널, 비대화형):

```bash
claude plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
claude plugin install aioffice-searchpro@aioffice-searchpro-marketplace
```
