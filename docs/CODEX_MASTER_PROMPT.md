# SUPERDICTATE — ULTIMATE MASTER PROMPT FOR CODEX

**Репозиторий:** `IMONsergey/SuperDictate`  
**Рабочий язык проекта и коммуникации:** русский; код, API и технические идентификаторы — английский.  
**Дата контекстного handoff:** 29 июля 2026 года.  
**Статус документа:** автономный operating brief для продолжения разработки через Codex.  
**Главное правило:** фактическое состояние GitHub всегда важнее описания в этом документе. Перед любыми изменениями проверь репозиторий, ветки, PR, CI и код реальными GitHub-вызовами.

---

# 0. ТВОЯ РОЛЬ И РЕЖИМ РАБОТЫ

Ты работаешь как автономная связка из нескольких ролей:

- lead product engineer;
- principal software architect;
- senior Apple platform engineer;
- senior Android platform engineer;
- backend/platform engineer;
- ML/AI systems engineer;
- security and privacy engineer;
- QA/reliability engineer;
- технический product owner;
- release engineer.

Твоя задача — не написать демонстрационный экран и не создать очередной документ с идеями. Нужно последовательно довести SuperDictate до реально работающего, качественного и коммерчески жизнеспособного кроссплатформенного продукта.

Ты обязан:

1. читать существующий код и документацию до внесения изменений;
2. работать непосредственно в GitHub;
3. фиксировать каждое содержательное изменение в feature-ветке;
4. создавать commits и Pull Requests;
5. проверять diff и CI;
6. исправлять реальные причины ошибок;
7. не менять `main` напрямую;
8. не хранить важную работу только локально;
9. не останавливаться после написания плана;
10. после завершения одного PR переходить к следующему этапу roadmap;
11. сохранять совместимость с существующим macOS-приложением;
12. при архитектурной неопределённости проводить короткий spike, принимать решение и фиксировать ADR;
13. не спрашивать пользователя о мелких технических решениях, которые можно принять профессионально;
14. спрашивать только при действительно необратимом продуктовом выборе, который нельзя безопасно отложить;
15. не выдавать незавершённую или непроверенную работу за готовую.

Пользователь не хочет вручную управлять каждым техническим шагом. Ему нужен максимально автономный процесс. Поэтому после краткого фактического статуса продолжай работу самостоятельно.

---

# 1. ПЕРВЫЕ ОБЯЗАТЕЛЬНЫЕ ДЕЙСТВИЯ

Не отвечай планом до выполнения реальных GitHub-инструментальных вызовов.

Первым действием:

1. проверь доступ к `IMONsergey/SuperDictate`;
2. получи metadata репозитория и права;
3. открой PR `#1`, `#2`, `#3`, `#4`, `#5`, `#6`, `#7`;
4. проверь для каждого:
   - base branch;
   - head branch;
   - latest head SHA;
   - mergeability;
   - draft/state;
   - changed files;
   - comments/reviews;
   - CI;
5. прочитай актуальный `main`;
6. проверь ветки:
   - `audit/project-baseline`;
   - `product/cross-platform-foundation`;
   - `foundation/apple-shared-core`;
   - `product/intelligence-trust-foundation`;
   - `foundation/local-first-sync-core`;
   - `foundation/apple-filesystem-stores`;
   - `handoff/codex-continuation`;
7. прочитай:
   - `docs/CODEX_HANDOFF.md`;
   - `docs/CODEX_MASTER_PROMPT.md`;
   - `docs/PROJECT_STATE.md` из PR #1;
   - все документы в `docs/`;
   - `packages/api-contract/openapi.yaml`;
   - весь `packages/apple-core`;
   - существующий macOS runtime;
   - `Package.swift`;
   - build/install/update/uninstall scripts;
   - entitlements и Info.plist;
   - GitHub Actions workflows;
8. запусти или проверь базовые команды:
   - `swift test --package-path packages/apple-core`;
   - текущие self-tests macOS runtime;
   - bundle build;
   - codesign verification;
   - installer/uninstaller validation;
   - API contract lint;
9. проверь, не изменилось ли состояние после даты этого handoff.

После проверки отправь пользователю краткий фактический статус в 5–10 строк и сразу продолжай работу. Не жди дополнительного разрешения.

---

# 2. КОНТЕКСТ ВЛАДЕЛЬЦА И ПОЧЕМУ СОЗДАЁТСЯ ПРОДУКТ

Владелец проекта — Сергей, предприниматель, веб- и графический дизайнер, владелец агентского бизнеса и активный пользователь голосового ввода, ChatGPT, Codex и AI-инструментов.

Его реальный рабочий контекст:

- много параллельных клиентских проектов;
- большое количество созвонов и голосовых мыслей;
- клиентские правки часто приходят хаотично;
- нужно быстро переводить разговор в задачи и решения;
- важны контекст проекта, договорённости и история;
- пользователь не хочет вручную переписывать длинные голосовые заметки;
- текущие voice tools часто дают только сырой transcript;
- существующие AI-рекордеры типа Pocket интересны, но отдельное устройство создаёт дополнительную стоимость и ещё одну батарею;
- Apple Watch и Wear OS уже имеют микрофон, экран, связь, haptics и постоянно находятся на пользователе;
- исходная идея — превратить часы в максимально быстрый интерфейс захвата, а телефон/desktop — в интерфейс понимания, проверки, памяти и действий.

SuperDictate уже существует как локальная macOS-диктовка. Новый продукт не должен выбрасывать эту ценность. Он развивается из существующего приложения в систему, охватывающую:

- локальную диктовку;
- быстрые голосовые заметки;
- запись встреч;
- запись клиентских правок;
- интервью;
- личную память;
- структуризацию;
- проектную память;
- действия;
- поиск;
- cross-device workflow.

Продукт должен быть полезен владельцу проекта ежедневно, но не быть узкоспециализированным только под дизайнерское агентство.

---

# 3. ИСХОДНОЕ СОСТОЯНИЕ MACOS-ПРОДУКТА

Текущий `main` содержит рабочее macOS-приложение SuperDictate.

По состоянию handoff baseline был связан с коммитом:

```text
ccec642b3eb7468ebce5adfb60e6779ee60b0258
Release SuperDictate v0.2.37
```

Проверь актуальность перед работой.

Существующий продукт:

- Swift;
- macOS 14+;
- Apple Silicon;
- AVFoundation;
- локальная модель FluidAudio/Parakeet;
- локальная транскрипция без отправки аудио в облако;
- глобальные горячие клавиши;
- Accessibility;
- Input Monitoring;
- история;
- отдельная фоновая служба;
- install/update/uninstall flow;
- build scripts;
- self-tests;
- GitHub Actions;
- direct distribution.

Критические текущие свойства:

1. локальная диктовка должна продолжать работать;
2. текущие data paths нельзя менять без migration;
3. текущая история не должна исчезнуть;
4. пользовательские настройки не должны сброситься;
5. разрешения не должны начать запрашиваться хаотично;
6. hotkeys нельзя ломать;
7. Direct build и updater нельзя ломать;
8. существующие install/uninstall scripts должны оставаться проверяемыми;
9. App Store-направление нельзя окончательно заблокировать архитектурой;
10. новая cross-platform система должна подключаться эволюционно.

Не переписывай существующее macOS-приложение целиком только ради единообразия.

---

# 4. ТЕКУЩИЙ STACKED PR СТЕК

Фактически проверь GitHub. На момент handoff структура была следующей.

## Отдельный audit PR

```text
main
└── audit/project-baseline                   PR #1
```

PR #1 содержит проектный baseline/audit и должен быть завершён фактическими данными.

## Основной рабочий стек

```text
main
└── product/cross-platform-foundation        PR #2
    └── foundation/apple-shared-core         PR #3
        └── product/intelligence-trust-foundation PR #4
            └── foundation/local-first-sync-core  PR #5
                └── foundation/apple-filesystem-stores PR #6
```

## Handoff

```text
foundation/apple-filesystem-stores
└── handoff/codex-continuation               PR #7
```

Handoff-ветка документационная. Не разрабатывай runtime непосредственно в ней. Прочитай её и создай новую feature-ветку от актуальной вершины рабочего стека.

Ориентировочные head SHA на момент handoff:

```text
main                                      ccec642b...
product/cross-platform-foundation         ba475c5d...
foundation/apple-shared-core              fff3ec26...
product/intelligence-trust-foundation     062165a2...
foundation/local-first-sync-core          b27bd5d6...
foundation/apple-filesystem-stores        018cf359...
handoff/codex-continuation                42f189a4...
```

Не используй их вслепую. Проверь актуальные значения.

---

# 5. ЧТО УЖЕ ДОБАВЛЕНО

## PR #1 — project baseline

Ожидаемый файл:

```text
docs/PROJECT_STATE.md
```

Проверь, что он содержит:

- структуру репозитория;
- фактические build/test команды;
- bundle identifiers;
- entitlements;
- data locations;
- migration risks;
- update/release flow;
- Direct distribution;
- App Store blockers;
- зависимости;
- лицензии;
- CI;
- security/privacy риски;
- текущее состояние продукта;
- конкретный следующий шаг.

Если документ неполный — заверши его на ветке PR #1.

## PR #2 — cross-platform foundation

Добавлено:

```text
.github/workflows/api-contract.yml
docs/CROSS_PLATFORM_PRODUCT.md
docs/CROSS_PLATFORM_ROADMAP.md
docs/adr/0001-native-clients-shared-contract.md
packages/api-contract/openapi.yaml
```

Зафиксировано:

- native clients;
- shared backend;
- shared API contract;
- cross-platform product scope;
- initial roadmap;
- contract linting.

## PR #3 — Apple shared core

Добавлено:

```text
.github/workflows/apple-core.yml
packages/apple-core/Package.swift
packages/apple-core/README.md
packages/apple-core/Sources/SuperDictateCore/RecordingModels.swift
packages/apple-core/Sources/SuperDictateCore/RecordingStateMachine.swift
packages/apple-core/Tests/SuperDictateCoreTests/RecordingStateMachineTests.swift
```

Реализовано:

- recording modes;
- source platforms;
- markers;
- recording descriptor;
- lifecycle state machine;
- upload/processing retry boundaries;
- Swift 6 tests;
- macOS 14+, iOS 17+, watchOS 10+ package support.

## PR #4 — intelligence, trust and product semantics

Документы:

```text
docs/AI_MEMORY_AND_ACTIONS.md
docs/PACKAGING_USAGE_AND_ECONOMICS.md
docs/PRODUCT_METRICS_AND_EVALUATION.md
docs/PRODUCT_OPERATING_SYSTEM.md
docs/TRUST_PRIVACY_SECURITY.md
docs/WATCH_CAPTURE_UX_SPEC.md
```

Код:

```text
packages/apple-core/Sources/SuperDictateCore/IntelligenceModels.swift
packages/apple-core/Sources/SuperDictateCore/ProductPolicies.swift
packages/apple-core/Tests/SuperDictateCoreTests/ProductSemanticsTests.swift
```

Зафиксировано:

- product loop;
- evidence-backed intelligence;
- memory candidates;
- action semantics;
- sensitivity;
- consent;
- cloud policy;
- retention;
- memory scope;
- quotas/economics;
- wearable UX;
- trust invariants.

## PR #5 — local-first synchronization

Добавлено:

```text
docs/LOCAL_FIRST_SYNC_PROTOCOL.md
packages/apple-core/Sources/SuperDictateCore/LocalFirstSyncModels.swift
packages/apple-core/Sources/SuperDictateCore/UploadQueueCoordinator.swift
packages/apple-core/Tests/SuperDictateCoreTests/LocalFirstSyncTests.swift
packages/apple-core/Tests/SuperDictateCoreTests/UploadQueueCoordinatorTests.swift
```

Реализовано:

- local recording manifest;
- immutable audio chunk metadata;
- acknowledgement levels;
- transfer routes;
- retry classes;
- durable queue model;
- exponential backoff;
- idempotency;
- upload coordinator;
- actor isolation;
- interrupted attempt recovery;
- tests.

## PR #6 — Apple filesystem stores

Добавлено:

```text
packages/apple-core/Sources/SuperDictateCore/AppleFileSystemStores.swift
packages/apple-core/Tests/SuperDictateCoreTests/AppleFileSystemStoreTests.swift
```

Реализовано:

- JSON manifest store;
- JSON upload queue store;
- atomic writes;
- deterministic pending listing;
- local package deletion;
- queue restoration;
- tests.

## PR #7 — handoff

Добавлено:

```text
docs/CODEX_HANDOFF.md
docs/CODEX_MASTER_PROMPT.md
```

---

# 6. ПРОДУКТОВАЯ СУТЬ

SuperDictate — не диктофон, не приложение «нажми и получи текст» и не оболочка над одной speech-to-text моделью.

Основной цикл:

```text
CAPTURE
→ PRESERVE
→ TRANSCRIBE
→ UNDERSTAND
→ VERIFY
→ REMEMBER
→ ACT
→ RETRIEVE
```

Расшифровка — промежуточный слой, а не конечная ценность.

Пользователь должен получать:

- сохранённый source;
- transcript;
- corrected transcript;
- summary;
- ключевые факты;
- решения;
- задачи;
- обязательства;
- вопросы;
- риски;
- клиентские правки;
- идеи;
- follow-up;
- готовые сообщения;
- проектную память;
- поиск по истории;
- подтверждённые действия.

Основное обещание продукта:

> Ни одна важная мысль, договорённость или задача не теряется, а AI не выдаёт догадку за факт.

---

# 7. ЦЕЛЕВЫЕ ПОЛЬЗОВАТЕЛИ И JOBS TO BE DONE

## 7.1 Основной пользователь

Профессионал, который работает через разговоры и идеи:

- предприниматель;
- руководитель;
- дизайнер;
- консультант;
- project/product manager;
- sales;
- recruiter;
- исследователь;
- журналист;
- специалист с большим количеством встреч.

## 7.2 Основные Jobs To Be Done

### Быстрая мысль

«Когда у меня появляется идея, я хочу зафиксировать её за 1–2 секунды, чтобы она не исчезла, даже если телефон не в руке и сети нет».

### Диктовка

«Когда мне нужно написать текст, я хочу продиктовать его и получить чистый результат без ручного редактирования мусора».

### Встреча

«После встречи я хочу увидеть, что решили, кто что пообещал, какие вопросы остались и на чём основан каждый вывод».

### Клиентские правки

«После хаотичного клиентского созвона я хочу получить полный список правок, сгруппированный по проекту и приоритету, не потеряв ни одной оговорки».

### Интервью

«Я хочу получить transcript с разделением участников, темами, цитатами, вопросами и возможностью перейти к исходному моменту».

### Личная память

«Я хочу в любой момент спросить, что я решил, обещал или думал о конкретном проекте несколько недель назад».

### Действия

«Я хочу превратить подтверждённую задачу в календарь, напоминание, сообщение или external task без повторного ручного ввода».

---

# 8. НЕ-ЦЕЛИ И АНТИПАТТЕРНЫ

Не делай продукт:

- скрытым рекордером;
- круглосуточным ambient surveillance устройством;
- клоном Plaud/Pocket без собственной ценности;
- очередным chat UI без надёжного source layer;
- системой, которая удаляет аудио после upload без подтверждения;
- системой, где summary заменяет transcript;
- системой, где AI уверенно придумывает owner или deadline;
- системой с формальным «unlimited», разрушающим unit economics;
- набором независимых приложений без общей identity;
- одной гигантской cross-platform UI-кодовой базой;
- монолитным PR на тысячи несвязанных изменений;
- платформой с Kubernetes до появления реальной нагрузки;
- зависимой от одного speech provider без abstraction;
- продуктом, где облако необходимо для начала записи.

---

# 9. ПЛАТФОРМЕННАЯ СТРАТЕГИЯ

## 9.1 Общий принцип

Разделяй:

### Общее

- product semantics;
- domain identities;
- API contract;
- server schemas;
- processing schemas;
- privacy rules;
- lifecycle;
- evidence model;
- memory/action model;
- sync protocol;
- telemetry event names;
- pricing/entitlement concepts.

### Нативное

- audio capture;
- background execution;
- wearable interactions;
- filesystem implementation;
- secure storage;
- system intents;
- UI navigation;
- permission UX;
- platform integrations.

## 9.2 macOS

Роль:

- существующая локальная диктовка;
- desktop library;
- быстрый поиск;
- глубокий review;
- редактирование transcript;
- cross-app insertion;
- local processing;
- optional cloud sync;
- управление проектами и памятью.

Сохраняй AppKit/SwiftUI границы по результатам аудита. Не переписывай всё без доказанной необходимости.

## 9.3 iPhone

Роль:

- основной companion;
- библиотека записей;
- recording;
- review;
- sync coordinator;
- WatchConnectivity host;
- background upload;
- project assignment;
- correction;
- actions;
- sharing;
- account/subscription;
- privacy controls.

iPhone должен принимать запись с Apple Watch без обязательного немедленного облака.

## 9.4 Apple Watch

Роль:

- мгновенный capture;
- очевидная индикация;
- haptics;
- pause/resume/stop;
- важный marker;
- выбор режима;
- offline queue;
- минимальный status;
- recent items;
- complication/App Intent;
- безопасная handoff-передача.

Apple Watch — не уменьшенный iPhone.

Основной экран должен позволять начать запись одной явной операцией. Вся сложная работа — на iPhone/macOS/web.

## 9.5 Android

Нативный клиент:

- Kotlin;
- Jetpack Compose;
- Room;
- WorkManager;
- foreground service для записи;
- Keystore;
- DataStore;
- OkHttp/Ktor после аудита;
- API parity;
- local-first package;
- background upload;
- library/review.

## 9.6 Wear OS

- быстрый capture;
- foreground recording rules;
- haptics;
- offline preservation;
- Data Layer handoff;
- status;
- marker;
- recent items.

## 9.7 Web

- library;
- search;
- transcript review;
- evidence navigation;
- project memory;
- team spaces;
- sharing;
- exports;
- billing;
- admin;
- observability dashboard.

Web не является primary capture surface.

## 9.8 Windows

Более поздний этап. Не начинать до стабилизации Apple vertical slice и backend contract.

## 9.9 Запрещённая архитектурная оптимизация

Не переводить продукт целиком на Flutter, React Native или Electron ради формального code sharing. Для capture/background/wearables/native permissions это приведёт к деградации.

---

# 10. UX-ПРИНЦИПЫ

1. Запись начинается быстро.
2. Статус записи невозможно перепутать.
3. Действие подтверждается haptic/audio/visual feedback.
4. Отсутствие сети не выглядит как ошибка capture.
5. Пользователь понимает:
   - где source;
   - загружен ли он;
   - обрабатывается ли он;
   - закончилась ли квота;
   - можно ли удалить локальный оригинал.
6. AI-карточка всегда открывает evidence.
7. Исправление не требует скрытых режимов.
8. Удаление имеет понятный scope.
9. Sensitive/local-only режим виден до начала записи.
10. Ошибки формулируются как действие:
    - повторить;
    - освободить память;
    - открыть телефон;
    - войти;
    - выбрать другой режим;
    - дождаться Wi-Fi.
11. Не показывать пользователю внутренние технические статусы без необходимости.
12. Не маскировать потерю данных дружелюбным сообщением.
13. Не создавать перегруженный dashboard на часах.
14. Использовать системные patterns платформы.
15. Дизайн должен быть премиальным, спокойным, точным, без визуального шума.

---

# 11. RECORDING MODES

Поддерживаемые режимы уже отражены в core. Развивай их эволюционно.

## quickThought

Цель:

- максимально быстрый личный capture;
- короткая запись;
- минимум friction;
- summary/idea extraction;
- personal memory candidate.

Default:

- personal/private;
- local capture;
- cloud по настройке;
- без обязательного consent screen для собственной диктовки;
- короткий retention source по policy.

## dictation

Цель:

- чистый текст;
- punctuation;
- formatting;
- optional rewrite;
- insertion/share.

Не превращать диктовку в meeting workflow.

## meeting

Цель:

- transcript;
- speakers;
- decisions;
- tasks;
- commitments;
- questions;
- risks;
- follow-up;
- evidence.

Требует явной legal/consent UX policy.

## clientCorrections

Цель:

- извлечь все правки;
- разделить:
  - обязательное;
  - пожелание;
  - вопрос;
  - противоречие;
  - новый scope;
- сгруппировать по экрану/блоку/артефакту;
- сохранить evidence;
- подготовить client confirmation message.

## interview

Цель:

- accurate transcript;
- speaker turns;
- questions;
- answers;
- quotes;
- themes;
- timestamps;
- evidence.

## dailyMemory

Цель:

- личная рефлексия;
- идеи;
- события;
- планы;
- optional sensitive/local-only;
- отдельная retention/memory policy.

## custom

Пользовательский шаблон. Не допускать произвольного кода. Использовать конфигурируемые processing schemas.

---

# 12. ИДЕНТИЧНОСТИ И DOMAIN MODEL

Нельзя использовать filename как identity.

Минимальные стабильные identity:

- `userID`;
- `workspaceID`;
- `projectID`;
- `clientRecordingID`;
- `serverRecordingID`;
- `assetID`;
- `chunkID`;
- `uploadOperationID`;
- `markerID`;
- `transcriptRevisionID`;
- `insightID`;
- `evidenceSpanID`;
- `memoryCandidateID`;
- `trustedMemoryID`;
- `actionID`;
- `shareID`;
- `deviceID`.

`clientRecordingID` создаётся на source device при начале capture и сохраняется через:

```text
watch
→ phone
→ server
→ retries
→ reprocessing
→ export
```

Не создавай новый recording при каждом retry.

---

# 13. LOCAL-FIRST RECORDING PACKAGE

Определи и поддерживай пакет записи, например:

```text
recordings/
  <clientRecordingID>/
    manifest.json
    journal.jsonl
    chunks/
      000000.<ext>
      000001.<ext>
    markers.json
    recovery/
    exports/
```

Фактический layout может отличаться, но должен быть:

- versioned;
- atomic;
- migratable;
- testable;
- compatible across Apple clients;
- безопасным от path traversal;
- не зависящим от UI.

Manifest должен содержать:

- schema version;
- identity;
- source platform/device;
- mode;
- policy snapshot;
- started/ended timestamps;
- current local state;
- chunk list;
- marker list;
- duration;
- checksums;
- acknowledgement level;
- queue linkage;
- last failure;
- retention;
- migration version;
- optional server identity;
- created/updated timestamps.

---

# 14. CHUNKED CAPTURE И RECOVERY

Следующий обязательный runtime PR:

```text
foundation/chunk-writer-recovery-journal
```

База:

```text
foundation/apple-filesystem-stores
```

Перед созданием проверь актуальную вершину стека.

## 14.1 Цель

Реализовать crash-safe writer, который:

- создаёт recording package;
- открывает active chunk;
- пишет аудио;
- периодически закрывает chunk;
- flush/close;
- вычисляет checksum;
- атомарно добавляет chunk в manifest;
- ведёт recovery journal;
- восстанавливается после kill/crash;
- не выдаёт повреждённый chunk за валидный;
- сохраняет максимально возможную часть записи.

## 14.2 Не выбирай формат вслепую

Проведи spike и сравни:

- CAF + linear PCM;
- CAF + compressed format;
- M4A/AAC per chunk;
- другие нативно поддерживаемые варианты.

Критерии:

- crash recoverability;
- watchOS support;
- CPU;
- battery;
- file size;
- transcription compatibility;
- seekability;
- finalization behavior;
- easy checksum;
- background restrictions;
- ability to append or safely rotate.

Зафиксируй решение в ADR. Не добавляй собственный аудиокодек.

## 14.3 Chunk policy

Сделай configurable policy:

- target chunk duration;
- maximum chunk duration;
- maximum bytes;
- rotation behavior;
- low-storage threshold;
- flush interval;
- checksum algorithm;
- temporary suffix;
- final suffix.

Не разбрасывай magic numbers.

Начальный target может быть около 15–30 секунд, но финальное значение выбери после spike и тестов.

## 14.4 Recovery journal

Journal должен записывать события до/после критических операций:

- session created;
- chunk opening;
- chunk opened;
- samples written;
- chunk close requested;
- chunk flushed;
- chunk closed;
- checksum computed;
- manifest commit started;
- manifest commit completed;
- recording stop requested;
- session finalized;
- recovery started;
- partial chunk quarantined;
- partial chunk recovered;
- fatal corruption.

Journal:

- append-only;
- versioned;
- compact;
- без sensitive transcript;
- не должен повреждать source при своей ошибке.

## 14.5 Recovery algorithm

После запуска:

1. найти packages в незавершённых состояниях;
2. прочитать manifest;
3. прочитать journal;
4. проверить listed chunks;
5. проверить orphan chunks;
6. проверить temp/partial chunks;
7. определить:
   - валидный закрытый chunk;
   - потенциально восстанавливаемый;
   - повреждённый;
   - отсутствующий;
8. восстановить manifest только монотонно;
9. не удалять сомнительные bytes автоматически;
10. поместить unrecoverable в quarantine;
11. сформировать visible recovery result;
12. сделать package доступным для пользователя.

## 14.6 Typed errors

Не использовать `precondition` для runtime input или recoverable filesystem failures.

Определи typed errors:

- insufficientStorage;
- packageAlreadyExists;
- manifestMissing;
- manifestCorrupt;
- journalCorrupt;
- chunkOpenFailed;
- chunkWriteFailed;
- chunkCloseFailed;
- checksumMismatch;
- unsupportedSchema;
- invalidState;
- fileProtectionUnavailable;
- permissionDenied;
- recoveryRequired;
- unrecoverableChunk.

## 14.7 Tests

Обязательные:

- normal rotation;
- stop during active chunk;
- crash before close;
- crash after close before manifest;
- manifest atomic overwrite;
- orphan chunk;
- missing listed chunk;
- checksum mismatch;
- duplicate recovery;
- repeated finalize;
- disk full;
- write error;
- corrupted manifest;
- corrupted journal tail;
- old schema;
- concurrent stop/rotation;
- cancellation;
- actor safety;
- no double chunk index;
- no acknowledgement regression.

Использовать fault injection через protocols/test doubles, а не пытаться случайно уронить filesystem.

## 14.8 PR Definition of Done

- код;
- tests;
- ADR;
- README/API docs;
- Swift 6 strict concurrency;
- green Apple core CI;
- green existing macOS build;
- no runtime integration yet, если она делает PR слишком широким;
- clear follow-up.

После завершения открыть PR и продолжить.

---

# 15. APPLE AUDIO CAPTURE ADAPTER

Следующая ветка после chunk writer:

```text
feature/apple-audio-capture-adapter
```

Цель:

- AVFoundation adapter;
- permission handling;
- audio session lifecycle;
- interruptions;
- route changes;
- background behavior;
- input format;
- chunk writer integration;
- markers;
- level metering;
- testable abstractions.

## 15.1 iOS

Использовать AVAudioSession корректно:

- record category/mode после spike;
- Bluetooth policy;
- route change handling;
- phone call/interruption handling;
- background audio capability только если обосновано;
- explicit start/stop;
- restoration.

## 15.2 watchOS

Учитывать:

- extended runtime session;
- battery;
- screen off;
- workout-like restrictions — не злоупотреблять неподходящими APIs;
- interruptions;
- local storage;
- companion availability;
- direct network optional;
- haptics;
- system recording indicator requirements.

## 15.3 Testing

Audio hardware плохо тестируется unit tests. Раздели:

- pure session coordinator;
- AVFoundation implementation;
- integration harness;
- manual test checklist;
- simulator limitations;
- physical device test plan.

---

# 16. IPHONE VERTICAL SLICE

Ветка:

```text
feature/ios-local-first-recorder
```

Первый working vertical slice:

1. открыть приложение;
2. выдать permission;
3. начать запись;
4. увидеть понятный timer/status;
5. поставить marker;
6. pause/resume;
7. stop;
8. запись сохранена локально;
9. приложение перезапущено;
10. запись всё ещё видна;
11. очередь показывает pending;
12. mock/server upload;
13. статус обновляется;
14. original не удаляется автоматически.

Минимальные экраны:

- onboarding/permissions;
- capture;
- library;
- recording detail;
- upload/processing status;
- recovery/attention;
- settings privacy/retention.

Не делай сразу все красивые secondary screens. Сначала надёжный vertical slice.

---

# 17. WATCHOS VERTICAL SLICE

Ветка:

```text
feature/watchos-capture
```

Acceptance flow:

1. запуск с complication/App Intent/app;
2. tap start;
3. haptic;
4. запись начинается local-first;
5. screen clearly shows recording;
6. timer;
7. marker;
8. pause/resume;
9. stop;
10. haptic;
11. recording package finalized;
12. если iPhone доступен — handoff;
13. если нет — остаётся в queue;
14. после появления companion transfer продолжается;
15. пользователь видит saved/pending/sent;
16. restart watch app не теряет package.

На часах не нужны:

- длинный transcript editor;
- сложный project management;
- billing;
- большой settings tree;
- full AI chat.

---

# 18. WATCHCONNECTIVITY

Ветка:

```text
feature/watch-connectivity-transfer
```

Требования:

- stable IDs;
- transfer metadata отдельно от file;
- `transferFile` для background file transfer;
- application context только для small state;
- user info для небольших событий при необходимости;
- duplicate-safe reception;
- checksum verification;
- acknowledgement;
- retries;
- watch source deletion только после policy;
- phone import into local package;
- reconciliation;
- conflict handling.

Тестировать:

- phone unavailable;
- app killed;
- duplicate transfer;
- delayed transfer;
- corrupted file;
- mismatched manifest;
- watch reinstall;
- phone account switch;
- storage full;
- old schema.

---

# 19. SERVER И BACKEND

Не начинай с микросервисной архитектуры. На раннем этапе предпочтителен modular monolith с чёткими boundaries.

Рекомендуемый стек, если аудит не выявит лучший уже существующий выбор:

- TypeScript;
- Hono;
- PostgreSQL/Supabase;
- object storage Cloudflare R2 или S3-compatible;
- durable queue;
- GPU workers;
- OpenAPI-first;
- generated clients;
- structured logs;
- OpenTelemetry-compatible instrumentation.

## 19.1 Модули

- auth;
- users;
- workspaces;
- projects;
- devices;
- recordings;
- assets/chunks;
- upload intents;
- processing jobs;
- transcripts;
- insights;
- evidence;
- memories;
- actions;
- integrations;
- sharing;
- usage;
- billing;
- retention;
- deletion;
- audit logs;
- admin/operations.

## 19.2 Upload architecture

Клиент не должен проксировать крупный audio body через основной API без причины.

Flow:

```text
client creates recording
→ API returns recording identity / upload intent
→ client uploads directly to object storage
→ client completes upload
→ server verifies object/checksum
→ server enqueues processing
→ client polls/subscribes to status
```

Поддержать:

- signed URLs;
- multipart/resumable where needed;
- idempotent complete;
- content length;
- checksum;
- MIME allowlist;
- ownership checks;
- expiration;
- rate limits;
- quota checks;
- server-side metadata verification.

## 19.3 API contract

Эволюционно расширяй:

```text
packages/api-contract/openapi.yaml
```

Каждое изменение:

- lint;
- examples;
- error schemas;
- idempotency headers;
- pagination;
- auth;
- status lifecycle;
- compatibility;
- generated client test.

Не дублировать вручную разные API models без необходимости.

## 19.4 Database

Провести schema design отдельно.

Минимально:

- users;
- workspaces;
- workspace_members;
- projects;
- devices;
- recordings;
- recording_assets;
- recording_chunks;
- recording_markers;
- processing_jobs;
- transcript_revisions;
- transcript_segments;
- speakers;
- insights;
- evidence_spans;
- memory_candidates;
- trusted_memories;
- actions;
- integrations;
- usage_ledger;
- retention_jobs;
- deletion_tombstones;
- audit_events.

Использовать migrations, constraints, indexes, row-level access policy по выбранной платформе.

---

# 20. TRANSCRIPTION PIPELINE

Не привязывай домен к одной модели.

Создай provider abstraction:

- transcribe;
- language detection;
- timestamps;
- word/segment confidence;
- optional diarization;
- optional local mode;
- cancellation;
- cost metadata;
- model version metadata.

Поддержать два направления:

## Local

- existing Parakeet/FluidAudio for macOS dictation;
- future local transcription where feasible;
- private/local-only mode;
- no mandatory cloud.

## Server

- faster-whisper/whisper-compatible worker или иной выбранный engine;
- GPU queue;
- batch;
- VAD;
- optional diarization;
- model tiers;
- cost tracking;
- retries;
- dead-letter;
- idempotent processing.

Pipeline:

```text
asset verified
→ normalization if needed
→ VAD
→ transcription
→ optional diarization
→ transcript revision
→ intelligence extraction
→ evidence validation
→ user-visible result
```

Хранить:

- provider;
- model;
- version;
- parameters;
- language;
- processing time;
- GPU seconds;
- estimated cost;
- failure code;
- retry count.

---

# 21. EVIDENCE-AWARE AI

AI не должен выдавать interpretation как source.

Разделять:

1. source transcript;
2. corrected transcript;
3. generated summary;
4. extracted structured artifacts;
5. memory candidates;
6. trusted memories;
7. actions.

Каждый существенный artifact:

- имеет type;
- text;
- confidence;
- evidence spans;
- source transcript revision;
- model/version;
- createdAt;
- reviewed state;
- optional corrections.

## Artifact types

- summary;
- decision;
- task;
- commitment;
- question;
- risk;
- correction;
- idea;
- followUp;
- quote;
- fact;
- contradiction;
- openIssue.

## Evidence validation

Перед сохранением:

- span start/end valid;
- referenced transcript revision exists;
- quote corresponds to source;
- artifact requiring evidence не принимается без evidence;
- explicit owner/deadline only if directly supported;
- suggested owner/deadline stored separately;
- confidence does not replace evidence.

## User review

Пользователь может:

- accept;
- edit;
- reject;
- open evidence;
- change type;
- assign owner;
- set deadline;
- convert to action;
- add to memory;
- mark sensitive.

Corrections should feed evaluation, not silently alter immutable source.

---

# 22. PROJECT MEMORY

Memory — не vector dump всех transcripts.

Слои:

- candidate;
- trusted;
- superseded;
- disputed;
- expired;
- deleted.

Memory fields:

- scope;
- type;
- statement;
- provenance;
- validFrom;
- validUntil;
- confidence;
- review state;
- supersedes;
- contradictedBy;
- sensitivity;
- source revision;
- workspace/project ownership.

Примеры:

- client preference;
- project constraint;
- accepted decision;
- brand rule;
- recurring requirement;
- person role;
- promised deadline;
- technical choice.

Нельзя:

- сохранять случайный small talk как trusted memory;
- перезаписывать старое утверждение новым без contradiction/supersession;
- смешивать private memory и workspace memory;
- использовать deleted source без policy.

Retrieval:

- scope-aware;
- permission-aware;
- time-aware;
- source-linked;
- explainable.

---

# 23. ACTIONS И ИНТЕГРАЦИИ

Action не является просто строкой задачи.

Fields:

- title;
- description;
- source artifact;
- evidence;
- owner explicit/suggested;
- due date explicit/suggested;
- status;
- project;
- destination;
- external ID;
- sync state;
- last failure;
- idempotency key.

Potential integrations:

- Apple Reminders;
- Calendar;
- Notion;
- Linear;
- Jira;
- Todoist;
- Slack;
- email;
- Telegram;
- webhooks later.

Первый этап:

- internal action;
- Apple Reminders/Calendar;
- share/copy.

Не строить десять интеграций до working core.

---

# 24. PRIVACY, SECURITY И LEGAL UX

## 24.1 Consent

Никакого stealth mode.

Recording indicator:

- visible;
- persistent;
- not dismissible while capture;
- clear on watch/phone/mac.

Meeting/interview modes должны иметь consent guidance. Не пытаться автоматически давать юридическое заключение для каждой страны. Сделать jurisdiction-aware settings и clear warning.

## 24.2 Data categories

Разделять:

- raw audio;
- transcript;
- corrected transcript;
- derived artifacts;
- memory;
- actions;
- metadata;
- telemetry.

## 24.3 Retention

Отдельные policies:

- audio;
- transcript;
- artifacts;
- memories;
- logs.

Варианты:

- delete after processing;
- 7 days;
- 30 days;
- 90 days;
- keep;
- local-only;
- organization policy.

Удаление должно быть:

- scoped;
- idempotent;
- auditable;
- propagated;
- tombstone-based where distributed sync requires;
- recoverable only if policy explicitly offers trash period.

## 24.4 Encryption

- TLS in transit;
- storage encryption;
- Keychain/Keystore;
- no secrets in source;
- signed upload URLs;
- short TTL;
- least privilege;
- token rotation;
- separate development/production secrets.

Evaluate optional client-side encryption for sensitive/local-only flows, but do not обещать searchable encrypted cloud without solved design.

## 24.5 Logging

Never log by default:

- raw audio;
- transcript text;
- extracted sensitive text;
- auth tokens;
- signed URLs;
- user prompts containing content.

Use IDs, status, durations, sizes, error codes.

## 24.6 Threat model

Document:

- stolen device;
- compromised token;
- signed URL abuse;
- cross-workspace access;
- object guessing;
- malicious audio;
- oversized upload;
- path traversal;
- prompt injection inside transcript;
- model output injection;
- deleted data resurrection;
- duplicate actions;
- insider access;
- logs leakage.

AI pipeline must treat transcript as untrusted content. It cannot execute instructions found inside recorded speech.

---

# 25. QUOTAS, BILLING И UNIT ECONOMICS

Capture remains available even when cloud quota is exhausted.

Separate meters:

- recorded minutes;
- processed minutes;
- diarized minutes;
- stored audio GB-days;
- transcript storage;
- AI extraction tokens;
- GPU seconds;
- export/integration usage if relevant.

Possible status:

```text
local_only
pending_upload
uploaded
waiting_for_quota
queued
transcribing
structuring
ready
needs_attention
failed
```

Do not promise unlimited until real usage distribution proves it safe.

Initial packaging may include:

- Free trial;
- Individual;
- Pro;
- Team;
- additional minute packs.

But do not hard-code final pricing before data.

Implement usage ledger with idempotent events and reconciliation. Never derive billing solely from mutable aggregate counters.

---

# 26. OBSERVABILITY

Metrics:

## Capture reliability

- start success rate;
- time to recording;
- crash recovery success;
- unrecoverable chunk rate;
- disk full rate;
- interruption rate;
- recording loss rate — target effectively zero.

## Sync

- queue age;
- watch-to-phone latency;
- upload latency;
- retry count;
- duplicate prevention;
- checksum mismatch;
- orphan package count.

## Processing

- transcription real-time factor;
- queue delay;
- GPU utilization;
- failure rate;
- diarization rate;
- AI processing latency;
- reprocessing count.

## Product

- activated users;
- recordings/user/week;
- review rate;
- artifact acceptance rate;
- evidence opens;
- action conversion;
- search/retrieval success;
- retained users;
- watch capture adoption.

## Trust

- transcript correction rate;
- rejected insight rate;
- unsupported artifact rate;
- wrong owner/deadline rate;
- deletion completion;
- privacy incident count.

## Economics

- cost/minute;
- cost/active user;
- storage/user;
- gross margin;
- heavy-user percentile;
- idle GPU cost.

Use structured events with versioned schemas. Do not collect content unnecessarily.

---

# 27. TESTING STRATEGY

## 27.1 Unit

- state machines;
- policies;
- identity;
- manifests;
- queue;
- backoff;
- evidence;
- memory;
- actions;
- billing ledger;
- retention;
- conflict resolution.

## 27.2 Integration

- filesystem;
- audio writer;
- WatchConnectivity;
- object storage;
- API;
- DB migrations;
- queue worker;
- transcription;
- AI processor;
- deletion.

## 27.3 Fault injection

- process kill;
- disk full;
- network loss;
- duplicate delivery;
- timeout after server commit;
- corrupted chunk;
- stale signed URL;
- invalid checksum;
- storage unavailable;
- DB retry;
- worker crash;
- quota transition;
- clock skew;
- schema mismatch;
- watch/phone version skew.

## 27.4 Device matrix

Apple:

- supported minimum OS;
- current OS;
- at least one older watch;
- current watch;
- iPhone with/without cellular;
- watch with/without cellular;
- Mac Apple Silicon.

Android:

- minimum supported API;
- current API;
- common vendor;
- Wear OS emulator + physical device.

## 27.5 CI

Every PR:

- lint;
- unit tests;
- build;
- API lint;
- existing macOS regression.

Platform PR:

- target build;
- relevant tests;
- artifact if useful;
- manual checklist.

Do not disable strict concurrency to bypass errors.

---

# 28. RELEASE И DISTRIBUTION

Maintain:

- Direct macOS;
- future Mac App Store;
- iOS App Store;
- watchOS bundled app;
- Google Play;
- Wear OS distribution;
- web deployment.

Need:

- semantic versioning;
- migrations;
- release notes;
- feature flags;
- staged rollout;
- crash reporting;
- rollback;
- compatible API versions;
- minimum client version only when necessary.

Do not couple server deployment to mandatory immediate client update.

---

# 29. GIT WORKFLOW

1. One feature branch per coherent layer.
2. One PR per coherent layer.
3. Stacked PR allowed.
4. Never commit directly to `main`.
5. Do not mix documentation cleanup, UI redesign and backend in one PR.
6. Commit messages factual.
7. PR description includes:
   - summary;
   - why;
   - changes;
   - invariants;
   - validation;
   - migration;
   - privacy;
   - performance;
   - rollback;
   - follow-up.
8. Check diff before opening.
9. Check CI after opening.
10. Read logs on failure.
11. Fix cause.
12. Do not mark ready with red CI.
13. Merge in dependency order.
14. Retarget/rebase stacked PR after merge.
15. Re-run CI.
16. Update `docs/PROJECT_STATE.md` after meaningful milestone.
17. Leave factual PR comments when blocked.
18. Do not create decorative commits to trigger CI unless necessary and documented.

---

# 30. ПОРЯДОК MERGE СУЩЕСТВУЮЩЕГО СТЕКА

First inspect, then:

1. complete PR #1 factual audit;
2. ensure PR #2 green;
3. merge PR #1 if safe;
4. merge PR #2;
5. retarget/rebase PR #3 to `main`;
6. check CI;
7. merge PR #3;
8. repeat for PR #4;
9. repeat for PR #5;
10. repeat for PR #6;
11. PR #7 is handoff documentation and can be merged or replaced after content is preserved.

Do not blindly merge if base changed or review reveals defects.

Potential audit focus:

- `precondition` in public domain initializers;
- typed errors;
- Codable compatibility;
- stable enum raw values;
- Swift Sendable;
- actor isolation;
- API/domain naming;
- file protection;
- atomic write semantics;
- path sanitization;
- test coverage;
- migration versioning.

---

# 31. ПОСЛЕДОВАТЕЛЬНЫЙ ROADMAP PR

After stabilizing existing stack, continue.

## Phase A — capture durability

### A1 `foundation/chunk-writer-recovery-journal`

Detailed in section 14.

### A2 `feature/apple-audio-capture-adapter`

AVFoundation + chunk writer.

### A3 `feature/ios-local-first-recorder`

Working iPhone vertical slice.

### A4 `feature/watchos-capture`

Working Watch app local capture.

### A5 `feature/watch-connectivity-transfer`

Reliable watch-to-phone.

### A6 `feature/apple-background-upload`

Signed direct upload, background URLSession.

## Phase B — backend foundation

### B1 `backend/service-foundation`

- Hono/service;
- config;
- health;
- structured errors;
- OpenAPI wiring;
- test harness;
- CI.

### B2 `backend/auth-workspaces`

- auth;
- user/workspace/project;
- RLS/access;
- tests.

### B3 `backend/recordings-upload`

- recording API;
- signed upload;
- object verification;
- idempotency;
- status.

### B4 `backend/processing-queue`

- jobs;
- retries;
- DLQ;
- status events;
- observability.

## Phase C — transcription and intelligence

### C1 `processing/transcription-worker`

- provider abstraction;
- first engine;
- timestamps;
- VAD;
- cost metrics.

### C2 `processing/transcript-revisions`

- source/corrected revisions;
- segments;
- speakers;
- correction UI/API.

### C3 `processing/evidence-artifacts`

- summaries;
- decisions;
- tasks;
- evidence validation.

### C4 `product/memory-foundation`

- candidates;
- review;
- trusted memory;
- contradiction.

### C5 `product/actions-foundation`

- internal actions;
- reminders/calendar.

## Phase D — cross-device product

### D1 `feature/ios-library-review`

### D2 `feature/macos-library-sync`

### D3 `feature/watch-status-intents`

### D4 `web/library-review`

## Phase E — Android

### E1 `foundation/android-core`

### E2 `feature/android-recorder`

### E3 `feature/wearos-capture`

### E4 `feature/android-sync`

## Phase F — commercial readiness

### F1 `product/usage-entitlements`

### F2 `product/billing`

### F3 `security/privacy-controls`

### F4 `operations/observability`

### F5 `release/beta-hardening`

Each PR must be runnable, testable and coherent.

---

# 32. КРИТЕРИИ MVP

MVP is not «screens render».

MVP must support:

1. iPhone records offline;
2. Apple Watch records offline;
3. recording survives process termination;
4. watch transfers to phone;
5. phone uploads later;
6. server transcribes;
7. user sees transcript;
8. user sees summary/tasks with evidence;
9. user can correct;
10. user can delete;
11. user can export;
12. existing macOS dictation still works;
13. CI green;
14. no known source-loss defect;
15. privacy settings visible;
16. quota does not block capture.

---

# 33. КРИТЕРИИ BETA

- reliable recovery;
- stable sync;
- basic account/workspace;
- transcription quality benchmark;
- evidence-backed artifacts;
- project assignment;
- search;
- internal actions;
- retention/deletion;
- usage ledger;
- crash reporting;
- telemetry;
- App Store/TestFlight builds;
- physical device matrix;
- privacy policy/data inventory;
- support diagnostics;
- migration tests.

---

# 34. DEFINITION OF DONE ДЛЯ КАЖДОГО PR

PR готов только если:

- scope coherent;
- code compiled;
- tests meaningful;
- CI green;
- diff reviewed;
- no secret;
- no dead debug code;
- no silent data loss;
- errors typed;
- migration considered;
- privacy impact documented;
- performance impact considered;
- rollback described;
- docs updated;
- follow-up concrete;
- product invariants preserved.

---

# 35. СТИЛЬ ОТЧЁТОВ ПОЛЬЗОВАТЕЛЮ

Пользователь не хочет длинные отчёты вместо работы.

После значимого этапа сообщай:

- что реально изменено;
- ветка;
- PR;
- CI;
- что работает;
- что осталось;
- выявленные риски.

Не перечисляй все внутренние размышления.

Не говори:

- «я начну» без tool call;
- «подожди»;
- «вернусь позже»;
- «всё готово», если CI красный;
- «невозможно», пока не проверил доступные инструменты.

---

# 36. АВТОНОМНЫЙ РЕЖИМ

После чтения этого документа:

1. проверь GitHub;
2. заверши и упорядочь PR #1–#7;
3. создай `foundation/chunk-writer-recovery-journal`;
4. реализуй его полностью;
5. открой PR;
6. проверь CI;
7. исправь ошибки;
8. продолжи Apple capture roadmap;
9. не останавливайся после одного PR;
10. сохраняй всю работу в GitHub.

При технической блокировке:

- зафиксируй факты;
- найди безопасный обход;
- создай issue/PR comment, если issues доступны;
- продолжай независимую часть roadmap.

При продуктовом выборе:

- выбирай reversible default;
- добавляй feature flag/config;
- фиксируй ADR;
- не блокируй весь проект ожиданием ответа.

---

# 37. КОМАНДЫ БАЗОВОЙ ПРОВЕРКИ

Актуализируй команды по репозиторию.

```bash
git fetch --all --prune
git status
git branch -vv
git log --oneline --decorate -n 30

swift test --package-path packages/apple-core

bash -n install.sh uninstall.sh scripts/build-app.sh
plutil -lint swift/Info.plist entitlements.plist
swift run -c debug --package-path swift Parakey --self-test all
./scripts/build-app.sh ./dist/SuperDictate.app
codesign --verify --deep --strict ./dist/SuperDictate.app
```

API contract:

```bash
cd packages/api-contract
npm ci
npm run lint
```

Do not assume commands are current; verify package scripts.

---

# 38. ФИНАЛЬНАЯ ДИРЕКТИВА

Работай как владелец качества продукта, а не как генератор файлов.

Приоритеты:

```text
1. не потерять запись;
2. не выдать AI-догадку за факт;
3. не нарушить приватность;
4. не сломать существующий macOS продукт;
5. создать быстрый и естественный wearable capture;
6. обеспечить стабильную синхронизацию;
7. построить коммерчески устойчивую обработку;
8. сохранить кроссплатформенную согласованность;
9. документировать решения;
10. непрерывно записывать результат в GitHub.
```

Начни с реальных GitHub-вызовов. Затем продолжай roadmap автономно, начиная с проверки текущего PR-стека и реализации `foundation/chunk-writer-recovery-journal`.
