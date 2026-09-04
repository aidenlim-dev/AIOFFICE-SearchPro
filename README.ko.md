[English](README.md) | 한국어 | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

<div align="center">

# AIOFFICE-SearchPro

<sub>원본 프로젝트: <a href="https://github.com/fivetaku/insane-search">fivetaku/insane-search</a>. 이 저장소는 원본을 포크해 AIOFFICE 배포판으로 관리합니다.</sub>

**차단된 공개 페이지를 읽어내는 Claude Code / Codex 플러그인.** API 키도, 프록시 설정도 필요 없다.

<p>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/platform-Claude_Code-D97757?logo=claude" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Codex-supported-10A37F" alt="Codex 지원">
  <img src="https://img.shields.io/badge/API_key-not_required-3FB950" alt="API 키 불필요">
  <a href="https://github.com/aidenlim-dev/AIOFFICE-SearchPro/stargazers"><img src="https://img.shields.io/github/stars/aidenlim-dev/AIOFFICE-SearchPro?style=flat&color=F0B72F" alt="stars"></a>
</p>

<img src="assets/hero.png" width="860" alt="403 Forbidden, CAPTCHA, WAF 벽으로 막힌 사이트가 부서지며 AIOFFICE-SearchPro가 뚫고 들어가 실제 공개 게시물을 출처와 함께 반환하는 이미지. API 키 없음.">

</div>

---

평소 `403`이나 WAF 챌린지, 봇 차단에 걸리면 에이전트는 "그 페이지에 접근할 수 없습니다"로 끝난다. 이 플러그인은 바로 그 지점에서 개입한다. 공개 경로만 쓰는 에스컬레이션 체인을 돌려 하나가 실제 콘텐츠를 반환할 때까지 시도하고, 모델 컨텍스트에 그대로 넣을 수 있는 형태로 돌려준다.

**공개** 페이지를 읽는 도구다. 로그인과 페이월에서는 멈추고, 멈췄다고 말한다.

## 설치

**Claude Code** (대화형):

```bash
/plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
/plugin install aioffice-searchpro@aioffice-searchpro-marketplace
/reload-plugins
```

**Claude Code** (에이전트가 설치할 때, 또는 비대화형 셸. 위 슬래시 커맨드는 대화형 전용이라 에이전트가 못 쓴다):

```bash
claude plugin marketplace add aidenlim-dev/AIOFFICE-SearchPro
claude plugin install aioffice-searchpro@aioffice-searchpro-marketplace
```

**Codex** - 같은 저장소를 쓰고, Codex 네이티브 매니페스트가 `.codex-plugin/plugin.json`에 있다:

```bash
codex plugin marketplace add https://github.com/aidenlim-dev/AIOFFICE-SearchPro
codex plugin add aioffice-searchpro@aioffice-searchpro-marketplace
```

설치 후 에이전트를 재시작하거나 `/reload-plugins`를 실행한다. 실행에는 [uv](https://docs.astral.sh/uv/getting-started/installation/)가 필요하다. 첫 호출 때 `curl_cffi`, `yt-dlp`, 파서용 격리 uv 환경을 동기화하며, 시스템 Python은 건드리지 않는다.

### 기존 설치 업데이트

이미 설치한 사용자는 마켓플레이스와 플러그인을 모두 업데이트해야 새 버전이 적용된다. 아래 명령은 **Claude Code 대화창이 아니라 별도 터미널**에서 실행한다. `/plugin update ...`를 대화창에 입력하면 업데이트 대신 플러그인 관리 화면만 열린다.

```bash
claude plugin marketplace update aioffice-searchpro-marketplace
claude plugin update aioffice-searchpro@aioffice-searchpro-marketplace
claude plugin list
```

목록에서 `aioffice-searchpro`가 `1.6.1` 이상인지 확인한 뒤 Claude Code를 재시작한다. 열려 있는 세션에서는 `/reload-plugins`로 다시 불러올 수도 있다.

설치 확인은 설치된 사본에서 doctor를 돌리면 된다. 저장소를 다시 clone할 필요 없다:

```bash
bash ~/.claude/plugins/marketplaces/aioffice-searchpro-marketplace/setup/doctor.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\plugins\marketplaces\aioffice-searchpro-marketplace\setup\doctor.ps1"
```

doctor 요약의 OPTIONAL 항목(Node.js, 브라우저 폴백)은 없어도 플러그인이 동작한다. 브라우저 티어까지 쓰고 싶을 때만 설치한다: `setup/browser.sh`(macOS/Linux, `--install-node`) 또는 `setup/browser.ps1`(Windows, `-InstallNode`).

강의용 배포는 [COURSE_INSTALL.ko.md](COURSE_INSTALL.ko.md)를 쓴다.

## 쓰는 법

따로 배울 명령어는 없다. 평소처럼 요청하면 차단이 걸릴 때 플러그인이 알아서 동작한다:

> *"Claude Code 관련 레딧 인기 스레드 정리해줘."*
> *"이 유튜브 영상 자막 뽑아줘."*
> *"이 네이버 블로그 글 읽어줘."*
> *"이 URL의 판매 상품을 상품명, 가격, 링크 표로 정리해줘."*

자동 선택 여부가 애매하면 스킬을 명시해서 바로 호출할 수 있다:

```text
/aioffice-searchpro:aioffice-searchpro 이 URL의 판매 상품 리스트를 표로 정리해줘: https://example.com/products
```

엔진을 직접 돌릴 때는:

```bash
bash setup/run-engine.sh "https://example.com/"
```

파싱할 페이지라면 같은 호출에서 본문을 저장한다. WAF 성공은 확률적이라, 성공한 응답을 버리고 같은 URL을 다시 부르는 낭비를 막는다:

```bash
bash setup/run-engine.sh "https://example.com/" --json --output page.md --metadata page.fetch.json
```

자주 쓰는 플래그. 전체 목록은 `--help`:

| 플래그 | 효과 |
| :--- | :--- |
| `--output PATH` / `--metadata PATH` | 이번 시도의 본문과 결과 JSON을 저장 |
| `--selector CSS` | 챌린지 껍데기가 아니라 실제 페이지가 떴다는 양성 증거 |
| `--no-markdown` | 마크다운 변환 없이 raw HTML 반환 |
| `--maincontent` | nav/footer/광고를 걷어내고 본문만 |
| `--device mobile` | 모바일 경로로 고정 |
| `--trace` | 모든 시도와 실패 이유 출력 |

## 어떻게 뚫나

4개 티어이고, 앞 단계가 실패하거나 차단 신호를 감지할 때만 다음이 돌아간다:

| 티어 | 하는 일 |
| :--- | :--- |
| **Phase 0** | 일반 크롤러가 추측할 수 없는 공식 공개 경로. 레딧 `.rss`, X `tweet-result`/oEmbed, 유튜브 `yt-dlp`, Threads 인라인 `video_versions` |
| **Phase 1** | 저렴한 탐색: 공개 API 리더, syndication 게이트웨이, 모바일 / `.json` / `/rss` URL 변형 |
| **Phase 2** | `curl_cffi` TLS 지문 위장. 지문 다양성 순으로 정렬하고, 브라우저 신원 일체(실제 TLS 지문, 쿠키 워밍, 리퍼러 체인)를 갖춘다 |
| **Phase 3** | 실제 브라우저. 자동화 자체를 지문화하는 게이트용 프로토콜 스텔스 드라이버(nodriver, patchright), 그리고 사이트가 내부적으로 쓰는 JSON API를 드러내는 네트워크 캡처 |

WAF 제품 9종(Cloudflare, Akamai, DataDome, PerimeterX, Kasada, Imperva, AWS WAF, F5, 미지의 챌린지 프로파일)을 프로파일링해 두고, 감지된 프로파일이 어떤 브라우저 티어를 시도할 가치가 있는지 결정한다.

`200`은 성공이 아니라 **검사 시작 조건**으로 다룬다. 4계층 검증(마커, 크기, 쿠키, 지정한 `--selector`)이 모두 통과해야 성공으로 인정한다.

<details>
<summary><strong>콘텐츠 처리 - 실제로 무엇이 돌아오나</strong></summary>

최종 소비자가 대개 모델의 컨텍스트 창이라, 반환 전에 정리를 거친다:

- **기본이 마크다운.** raw HTML 성공은 구조 보존 마크다운으로 변환된다(표는 표로, 코드는 펜스 유지). 끄려면 `--no-markdown`.
- **PDF와 빈 껍데기 구제.** PDF 응답은 텍스트로 추출하고, 보이는 HTML이 없는 SPA 껍데기는 JSON-LD `articleBody`나 렌더된 `innerText`로 폴백한다. 어떤 경로였는지는 `result.extraction_source`로 확인한다.
- **본문 추출**은 보일러플레이트가 방해될 때 `--maincontent`로.
- **실패 진단.** 실패한 요청에는 `block_class`가 붙는다. `bot_detection`(라우트 결과가 엇갈려 에스컬레이션 여지 있음) 또는 `infra_or_auth`(모든 라우트가 균일하게 401/404라 스텔스로는 불가). 재시도가 의미 있는지 판단하는 데 쓴다.
- **구조적으로 신뢰하지 않음.** 가져온 페이지 텍스트는 모델에 닿기 전에 신뢰할 수 없는 공개 웹 콘텐츠로 감싸 표시하고, 프롬프트 인젝션 위험도를 점수화한다.

선택 라이브러리가 없으면 실패하지 않고 raw 출력으로 격하된다.
</details>

<details>
<summary><strong>막힌 사이트를 재사용 가능한 레시피로</strong></summary>

HTML은 중무장돼 있어도 사이트 자체의 JSON API는 얕은 경우가 많다. `scripts/endpoint_miner.py`가 엔드포인트를 정적으로 발굴하고, patchright 템플릿이 렌더 중 XHR을 캡처한다. 결과를 `recipes/<도메인>/recipe.yaml`로 저장하면 이후 요청은 격자를 건너뛰고 API로 직행한다.

`INSANE_AUTO_FORGE=1`을 주면 체인이 실패할 때 엔진이 스스로 한다. 렌더 → XHR 캡처 → 본문 겹침으로 데이터 API 선별 → curl로 재현 → 레시피 저장. 자세한 내용은 [references/scraper-forge.md](skills/aioffice-searchpro/references/scraper-forge.md).
</details>

## 동작하는 곳

**X · 레딧 · 유튜브 · Threads · 해커뉴스 · 네이버 · 쿠팡 · 링크드인 · Medium · Substack · arXiv · GitHub · 스택오버플로우 · Bluesky · 마스토돈** 그리고 공개 페이지나 피드, `/rss`가 있는 모든 사이트.

플랫폼별 방식은 [PLATFORMS.md](PLATFORMS.md)에 있다.

## 하지 않는 것

공개 콘텐츠를 읽는 도구이고, 인증 우회 도구가 아니다.

- **로그인과 페이월에서 멈춘다.** 뚫으려 시도하지 않고 `authentication required`를 반환한다.
- 사용자를 대신해 로그인하지 않고, 자격증명을 저장하거나 전송하지 않는다.
- 모든 경로가 인증 없는 공개 엔드포인트와 문서화된 기법만 쓴다.
- 정말로 못 뚫을 때는 확신에 찬 실패 보고 대신 어떤 경로를 시도했고 무엇이 남았는지 밝힌다.

## 이 포크의 차이점

[fivetaku/insane-search](https://github.com/fivetaku/insane-search)에서 포크해 AIOFFICE 배포판으로 관리한다. 업스트림 엔진 개선은 계속 반영하고, 아래는 로컬 변경이다:

- **Codex 지원** - 네이티브 매니페스트, 로컬 설치 스크립트, 도구 이름 매핑으로 두 에이전트가 동일하게 동작한다.
- **우회 방지 라우팅** - 봇 보호 사이트에는 이 스킬이 지정 도구임을 문서에 명시해, 에이전트가 무거운 브라우저부터 꺼내들지 않게 한다.
- **프로파일 인지형 실패 안내** - 무조건 Playwright MCP를 가리키는 대신, 감지된 WAF 프로파일이 실제로 요구하는 경로를 안내한다.
- **원샷 저장** - `--output` / `--metadata`로 첫 호출에서 성공한 본문을 확보한다.
- **OS 네이티브 wrapper** - `setup/run-engine.{sh,ps1}`가 Windows와 Unix에서 `uv sync --frozen`으로 격리 환경을 관리한다.
- **실행 가능한 의존성 진단** - 로컬 Playwright가 없으면 "사용 불가"로 끝내지 않고 정확한 해결 명령을 알려준다.

버전 이력과 릴리스별 이식 메모는 [CHANGELOG.md](CHANGELOG.md)에 있다.

## 라이선스

MIT
