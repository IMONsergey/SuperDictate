# MASTER PROMPT FOR CODEX — SUPERDICTATE

Работай непосредственно в репозитории:

```text
IMONsergey/SuperDictate
```

Твоя роль — автономный lead product engineer, software architect и технический product owner. Нужно не просто написать несколько экранов, а последовательно довести SuperDictate до качественного кроссплатформенного продукта: macOS, iPhone, Apple Watch, Android, Wear OS и web, с local-first записью, надёжной синхронизацией, серверной транскрипцией, доказательной AI-обработкой, памятью и действиями.

Не отвечай общим планом до выполнения реальных GitHub-вызовов и чтения репозитория.

---

## 1. Первые обязательные действия

Первым действием выполни реальные GitHub-инструментальные вызовы:

1. проверь доступ к `IMONsergey/SuperDictate`;
2. открой и прочитай PR #1, #2, #3, #4, #5 и #6;
3. проверь актуальный `main`;
4. проверь ветки:
   - `audit/project-baseline`;
   - `product/cross-platform-foundation`;
   - `foundation/apple-shared-core`;
   - `product/intelligence-trust-foundation`;
   - `foundation/local-first-sync-core`;
   - `foundation/apple-filesystem-stores`;
   - `handoff/codex-continuation`;
5. проверь CI каждого открытого PR и latest head SHA;
6. прочитай:
   - `docs/CODEX_HANDOFF.md`;
   - `docs/PROJECT_STATE.md`, если он существует в PR #1;
   - все документы из `docs/`, добавленные PR #2–#6;
   - `packages/api-contract/openapi.yaml`;
   - весь `packages/apple-core`;
   - текущий macOS runtime, build scripts, entitlements и workflows.

Не полагайся на описание этого промпта там, где GitHub показывает более новое состояние. GitHub — источник истины.

После проверки дай пользователю только краткий фактический статус и продолжай работу. Не останавливайся на отчёте.

---

## 2. Базовое понимание продукта

SuperDictate должен стать не очередным диктофоном и не оболочкой над Whisper.

Продуктовый цикл:

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

Пользователь должен иметь возможность:

- мгновенно зафиксировать мысль;
- записать встречу;
- записать клиентские правки;
- продиктовать текст;
- поставить важный маркер во время разговора;
- получить transcript;
- получить summary;
- получить решения, задачи, обязательства, вопросы и риски;
- увидеть доказательство каждого существенного AI-вывода;
- подтвердить или исправить результат;
- создать действие;
- сохранить проверенную память проекта;
- найти спустя недели, кто что сказал и что было решено.

Основное обещание:

> Ни одна важная мысль, договорённость или задача не теряется, а AI не выдаёт догадку за факт.

---

## 3. Платформенная стратегия

### Apple

Используй нативный стек:

- Swift 6;
- SwiftUI;
- AVFoundation;
- WatchConnectivity;
- BackgroundTasks / URLSession background transfers;
- App Intents;
- WidgetKit / complications, где оправдано;
- actors и strict concurrency;
- Foundation filesystem;
- Keychain для секретов;
- системные privacy APIs.

Apple-платформы разделяют `SuperDictateCore`, но platform adapters остаются нативными.

### Android

Используй:

- Kotlin;
- Jetpack Compose;
- Wear Compose;
- WorkManager;
- Room;
- foreground service для допустимых сценариев записи;
- DataStore;
- Android Keystore;
- OkHttp/Ktor по результатам аудита.

Android должен реализовывать те же domain semantics и OpenAPI, но не копировать Swift буквально.

### Web

Web — библиотека, поиск, review, sharing, billing и администрирование. Не использовать web как основной wearable runtime.

### Запрет

Не переводить продукт целиком на Flutter, React Native или Electron только ради формальной «единой кодовой базы». Это ухудшит запись, background execution, watch integration и системный UX.

---

## 4. Неприкосновенные инварианты

Сохраняй следующие правила во всех PR.

### Capture и сохранность

1. Capture local-first.
2. Начало записи не зависит от наличия сети.
3. Сеть не может уничтожить или остановить сохранённый source.
4. Аудио пишется crash-safe chunks.
5. Закрытый chunk immutable.
6. Chunk считается закрытым только после корректного flush/close и проверки метаданных.
7. Один `clientRecordingID` сохраняется через watch, phone, desktop, server и retries.
8. Manifest обновляется атомарно.
9. Очередь передачи durable.
10. Операции idempotent.
11. Acknowledgement не регрессирует.
12. Удаление source не является автоматическим следствием upload.

### AI и доверие

1. Source transcript, corrected transcript и generated interpretation — разные сущности.
2. Summary не является источником истины.
3. Decision, task, commitment, memory и risk имеют evidence spans.
4. AI не придумывает владельца.
5. AI не придумывает deadline.
6. Suggested owner/deadline хранится отдельно от explicit owner/deadline.
7. Memory candidate не становится trusted memory без policy или подтверждения.
8. Contradiction не перезаписывает старую память молча.
9. Любая существенная AI-карточка должна открывать исходный фрагмент.
10. Пользователь может исправить transcript и derived artifact.

### Privacy и legal UX

1. Никакого stealth recording mode.
2. Активная запись всегда заметна пользователю.
3. Consent policy зависит от recording mode и jurisdiction settings.
4. Cloud processing — явная policy, а не скрытая отправка.
5. Sensitive recording может быть local-only.
6. Раздельные retention policies для audio, transcript, derived artifacts и memory.
7. Export, correction и deletion не блокируются премиумом.
8. Секреты не хранятся в репозитории или plain-text storage.
9. Логи не содержат raw audio, transcript или чувствительный контент по умолчанию.

### Экономика

1. Не обещать фальшивый unlimited.
2. Capture не блокируется исчерпанной cloud-квотой.
3. Quota может переводить processing в `waiting_for_quota`.
4. Storage retention управляется отдельно от processing minutes.
5. Диаризация и тяжёлые модели могут быть отдельным premium capability.
6. Все expensive paths должны иметь измеряемую unit cost.

### Compatibility

1. Не ломать существующий macOS runtime.
2. Не менять существующие пути данных без миграции.
3. Не ломать Direct distribution.
4. Не ухудшать будущую App Store-совместимость.
5. Не менять `main` напрямую.

---

## 5. Git workflow

Работай только через GitHub.

- Одна задача — одна feature-ветка.
- Один содержательный слой — один PR.
- Допускаются stacked PR.
- `main` напрямую не изменять.
- Не складывать несвязанные изменения в один PR.
- Не создавать пустые или декоративные PR.
- Каждый commit должен иметь понятное сообщение.
- После каждого PR проверять diff и CI.
- Не считать работу завершённой при красном CI.
- Не отключать проверку ради зелёного статуса.
- При падении Actions читать logs и исправлять причину.
- Перед merge проверять, не устарела ли база.
- Merge выполнять в правильном порядке.
- После merge retarget/rebase следующего stacked PR и снова проверять CI.

### Текущее дерево

Отдельно:

```text
main
└── audit/project-baseline             PR #1
```

Основной стек:

```text
main
└── product/cross-platform-foundation  PR #2
    └── foundation/apple-shared-core   PR #3
        └── product/intelligence-trust-foundation PR #4
            └── foundation/local-first-sync-core  PR #5
                └── foundation/apple-filesystem-stores PR #6
```

Служебная ветка:

```text
handoff/codex-continuation
```

Не делай runtime PR из handoff-ветки. Прочитай её, затем создавай новую ветку от актуальной вершины рабочего стека.

---

## 6. Работа с существующими PR

Сначала фактически оцени PR #1–#6.

### PR #1

Проверь, завершён ли factual audit:

- структура репозитория;
- фактические build/test команды;
- bundle identifiers;
- entitlements;
- data paths;
- distribution;
- release/update flow;
- CI;
- зависимости;
- лицензии;
- App Store blockers;
- security/privacy blockers.

Если документ неполон — заверши его в `audit/project-baseline`. Проверь CI. Подготовь к merge.

### PR #2–#6

Они stacked. Проверь:

- все ли PR mergeable;
- зелёный ли CI;
- нет ли review comments;
- не расходится ли OpenAPI с моделями;
- не дублируются ли types;
- корректна ли Swift 6 concurrency;
- нет ли precondition там, где публичный API должен возвращать typed error;
- нет ли незадокументированных migrations.

После ревью:

1. merge PR #1, если он готов и не конфликтует;
2. merge PR #2;
3. retarget/rebase PR #3 на `main`;
4. повторить до PR #6;
5. после каждого шага проверить CI.

Если merge сейчас рискован, не делай его вслепую. Исправь ветку и оставь фактический комментарий в PR.

---

## 7. Ближайшая реализация: chunk writer + recovery journal

Следующая рекомендуемая ветка:

```text
foundation/chunk-writer-recovery-journal
```

База:

```text
foundation/apple-filesystem-stores
```

### Цель

Превратить local-first модели и JSON stores в реально надёжную запись audio chunks на Apple platforms.

### Требования

Создай:

- `AudioChunkWriter` protocol;
- concrete Foundation/AVFoundation implementation;
- `RecordingRecoveryJournal`;
- chunk lifecycle;
- atomic manifest integration;
- checksum calculation;
- recovery scanner;
- corruption classification;
- storage-capacity checks;
- typed errors;
- fault-injection seams.

### Предлагаемый chunk lifecycle

```text
allocated
→ writing
→ flushing
→ closed
→ verified
```

Ошибки:

```text
partial
corrupt
missing
unreadable
insufficient_space
permission_denied
interrupted
```

### Правила

- новый chunk создаётся во временном имени;
- данные записываются последовательно;
- journal обновляется перед опасной операцией;
- после close вычисляется checksum;
- chunk переименовывается атомарно;
- manifest revision увеличивается;
- verified chunk больше не изменяется;
- crash между стадиями восстанавливается сканером;
- partial файл не выдается за complete recording;
- recovery не удаляет данные автоматически;
- ошибки видимы в domain model.

### Тесты

Обязательно:

- normal close;
- crash до первой записи;
- crash во время записи;
- crash после flush, до manifest update;
- crash после manifest update;
- truncated chunk;
- checksum mismatch;
- missing chunk;
- duplicate recovery;
- low disk;
- permission failure;
- repeated finalize;
- interrupted application restart;
- journal corruption;
- manifest corruption;
- recovery idempotency.

Тесты должны быть детерминированы. Для filesystem использовать temporary directories. Не использовать реальные часы или микрофон в unit tests.

### Definition of done

- `swift test --package-path packages/apple-core` зелёный;
- существующий macOS workflow зелёный;
- новый код документирован;
- PR не содержит UI;
- PR содержит риски и recovery semantics.

---

## 8. После chunk writer: Apple vertical slice

Создавай отдельные PR.

### 8.1 Apple capture adapter

Ветка:

```text
feature/apple-audio-capture-adapter
```

Реализовать:

- AVAudioSession configuration;
- microphone permission;
- interruption handling;
- route changes;
- input availability;
- background constraints;
- chunk writer integration;
- level metering;
- silence detection только как signal, не как удаление source;
- user-visible recording state;
- typed capture events.

Не делать обработку AI внутри capture adapter.

### 8.2 iPhone app foundation

Ветка:

```text
feature/ios-local-first-recorder
```

Минимальный end-to-end UX:

- onboarding;
- microphone permission;
- record;
- pause/resume при допустимости;
- marker;
- stop;
- local library;
- playback;
- upload state;
- processing state;
- retry;
- export;
- delete;
- privacy settings.

Архитектура:

- SwiftUI;
- dependency injection;
- core package;
- concrete filesystem stores;
- background URLSession;
- testable view models;
- accessibility;
- Dynamic Type;
- localisation foundation RU/EN.

### 8.3 watchOS app

Ветка:

```text
feature/watchos-capture
```

Часы — capture surface.

Основной экран:

- одна главная кнопка;
- короткий haptic;
- ясный recording indicator;
- duration;
- marker action;
- stop;
- queued/sent state;
- recoverable error.

Не переносить библиотеку телефона целиком на часы.

Поддержать:

- offline capture;
- local queue;
- low battery;
- low storage;
- interruption;
- companion unavailable;
- user-visible consent reminder;
- complication / Smart Stack entry;
- App Intent;
- Action button shortcut, где API и устройство позволяют;
- accessibility;
- haptic vocabulary.

### 8.4 WatchConnectivity

Ветка:

```text
feature/watch-connectivity-transport
```

Реализовать:

- stable recording identity;
- metadata first;
- chunk transfer;
- acknowledgements;
- retry;
- duplicate delivery;
- out-of-order arrival;
- phone unavailable;
- phone app terminated;
- watch app terminated;
- reconciliation;
- transfer progress;
- tombstone propagation.

---

## 9. Backend

Backend строить после или параллельно с устойчивым capture foundation, но отдельными PR.

### Рекомендуемый стек

- TypeScript;
- Hono;
- PostgreSQL / Supabase;
- Cloudflare R2 или другой S3-compatible object storage;
- signed direct upload;
- durable job queue;
- worker processes;
- OpenAPI-first;
- structured logs;
- tracing;
- metrics.

Не проксировать большие audio files через основной API без необходимости.

### Основной поток

```text
client creates recording
→ API issues upload intent
→ client uploads chunks directly
→ client completes manifest
→ backend verifies objects
→ transcription job
→ structuring job
→ evidence validation
→ result published
→ client sync
```

### Требования

- idempotent create;
- idempotent complete;
- chunk checksums;
- manifest revision;
- optimistic concurrency;
- retry-safe workers;
- dead-letter handling;
- processing stages;
- quota state;
- deletion state machine;
- provider abstraction;
- audit trail без raw content;
- GDPR-ready data export/deletion;
- no secrets in repo.

### Data model

Минимум:

- users;
- workspaces;
- devices;
- recordings;
- recording_assets;
- recording_chunks;
- upload_operations;
- transcript_revisions;
- transcript_segments;
- speakers;
- evidence_spans;
- insights;
- actions;
- memory_candidates;
- memories;
- contradictions;
- processing_jobs;
- usage_ledger;
- subscriptions;
- deletion_requests;
- share_links.

Миграции версионируются и тестируются.

---

## 10. Transcription infrastructure

Создать provider abstraction:

```text
TranscriptionProvider
```

Провайдеры:

- local Apple model, где уже используется;
- self-hosted faster-whisper;
- optional cloud fallback;
- future Android on-device provider.

### Self-hosted worker

- faster-whisper;
- VAD;
- batch support;
- GPU metrics;
- queue depth;
- real-time factor;
- language detection;
- forced language;
- segment timestamps;
- word timestamps при необходимости;
- no diarization in mandatory MVP path;
- diarization отдельным optional stage;
- encrypted object access;
- automatic cleanup.

### Не делать

- не отправлять raw audio в LLM;
- не смешивать transcription и summarisation;
- не использовать один огромный prompt без schemas;
- не хранить temporary objects бесконечно;
- не логировать transcript.

---

## 11. Evidence-aware intelligence

Обработка должна быть schema-driven.

Пайплайн:

```text
transcript
→ normalisation
→ segmentation
→ candidate extraction
→ evidence binding
→ validation
→ user-reviewable artifacts
→ memory candidates
→ actions
```

Artifacts:

- summary;
- key points;
- decisions;
- tasks;
- commitments;
- questions;
- risks;
- client corrections;
- quotes;
- topics;
- follow-up draft;
- project memory candidates.

Каждый существенный artifact:

- stable ID;
- type;
- text;
- confidence;
- evidence spans;
- source transcript revision;
- model/version;
- createdAt;
- review status;
- correction history.

### Guardrails

- нет evidence — нет trusted fact;
- owner inference хранится как suggestion;
- deadline inference хранится как suggestion;
- ambiguous utterance маркируется;
- contradiction создаётся как отдельный объект;
- исправление transcript инвалидирует зависимые artifacts;
- regeneration versioned;
- пользователь видит, что создано AI.

---

## 12. Memory

Память — не vector dump всех разговоров.

Memory scopes:

- personal;
- project;
- client;
- workspace;
- temporary session.

Memory candidate содержит:

- proposition;
- type;
- scope;
- evidence;
- source recording;
- source transcript revision;
- confidence;
- sensitivity;
- validFrom;
- validUntil;
- supersedes;
- contradiction state;
- review state.

Trusted memory появляется:

- после явного подтверждения;
- или по безопасной policy для низкорискового типа.

Нельзя автоматически доверять:

- обещаниям;
- финансовым данным;
- юридическим условиям;
- персональным чувствительным данным;
- дедлайнам;
- владельцам задач;
- медицинским данным;
- доступам и секретам.

Retrieval должен ссылаться на первоисточник.

---

## 13. Actions и интеграции

Action lifecycle:

```text
suggested
→ confirmed
→ synced
→ completed
→ cancelled
```

Интеграции позже, через adapters:

- Calendar;
- Reminders;
- Notion;
- Linear;
- Jira;
- Slack;
- email draft;
- Telegram/share sheet.

Никакого автоматического внешнего действия без понятного user intent, кроме заранее включённых безопасных правил.

Idempotency обязательна для внешних sync.

---

## 14. UX и дизайн

Дизайн premium, спокойный и функциональный. Вдохновение — системность и материалность качественных Apple-продуктов, но не копирование конкретного интерфейса или чужой айдентики.

Принципы:

- минимум экранов до capture;
- одна очевидная primary action;
- никакой декоративной «AI-магии»;
- состояния понятнее анимаций;
- хороший haptic feedback;
- высокая читаемость;
- доступность;
- явный offline state;
- явный privacy state;
- не перегружать часы;
- сложный review выполнять на телефоне/desktop;
- source всегда доступен из derived card;
- ошибки объяснять человечески.

Не начинать с визуального полирования до рабочего capture path.

---

## 15. Security и privacy engineering

Обязательные задачи:

- threat model;
- data classification;
- Keychain/Keystore;
- signed URLs;
- short TTL;
- scoped tokens;
- device revocation;
- encryption in transit;
- encryption at rest;
- optional client-side encryption research;
- delete propagation;
- account export;
- audit trail;
- log redaction;
- dependency scanning;
- secret scanning;
- SBOM;
- privacy manifest Apple;
- Android data safety mapping;
- App Store/Play Store privacy documentation.

Не заявлять end-to-end encryption, если сервер расшифровывает audio для transcription.

---

## 16. Observability

Измерять:

### Capture reliability

- capture starts;
- capture failures;
- recovered sessions;
- corrupt chunks;
- lost recordings — целевой показатель 0;
- transfer retries;
- queue age;
- sync latency.

### Processing

- queue depth;
- real-time factor;
- transcription latency;
- processing latency;
- failure rate;
- provider cost;
- GPU utilisation.

### AI quality

- transcript corrections;
- artifact acceptance;
- artifact edits;
- false decision rate;
- false owner rate;
- evidence coverage;
- memory rejection;
- contradiction frequency.

### Product

- activation;
- weekly captured minutes;
- processed recordings;
- watch-to-phone completion;
- task conversion;
- retrieval success;
- retention.

Не собирать raw content в analytics.

---

## 17. Testing strategy

### Unit

- state machines;
- policies;
- manifests;
- chunks;
- journals;
- queues;
- backoff;
- evidence validation;
- memory transitions;
- action transitions;
- usage ledger.

### Fault injection

- process kill;
- disk full;
- permission denied;
- network loss;
- duplicate upload;
- out-of-order chunk;
- checksum mismatch;
- expired signed URL;
- companion unavailable;
- server 5xx;
- quota exhausted;
- worker crash;
- model timeout;
- partial deletion.

### Integration

- watch → phone;
- phone → object storage;
- API → queue;
- worker → database;
- transcript → evidence artifacts;
- deletion propagation.

### UI

- permission denied;
- offline;
- interrupted;
- low storage;
- retry;
- accessibility;
- localisation;
- long titles;
- large text.

### Regression

Существующий macOS flow проверять после каждого stacked layer.

---

## 18. Coding standards

### Swift

- Swift 6;
- strict concurrency;
- `Sendable`;
- actors для mutable shared state;
- typed errors;
- dependency injection;
- public API documented;
- no hidden global mutable state;
- no blocking I/O on main actor;
- no `await` inside XCTest autoclosures;
- deterministic dates/UUID through injectable providers where needed;
- avoid `precondition` for recoverable external input;
- atomic writes;
- Codable migrations/versioning.

### TypeScript

- strict mode;
- runtime schema validation;
- no `any`;
- OpenAPI alignment;
- idempotency;
- typed error envelope;
- migrations;
- tests;
- no secrets.

### Kotlin

- coroutines;
- structured concurrency;
- Flow;
- sealed states/errors;
- Room migrations;
- WorkManager;
- lifecycle-safe capture;
- no platform behaviour hidden in common abstractions.

---

## 19. PR quality bar

Каждый PR должен содержать:

- Summary;
- Why;
- Architecture;
- Changes;
- Invariants;
- Tests;
- Migration;
- Privacy/security impact;
- Performance impact;
- Rollback;
- Follow-up.

Перед завершением PR:

1. inspect diff;
2. run targeted tests;
3. run existing regression;
4. inspect CI;
5. fix failures;
6. update docs;
7. leave factual status.

Не писать «готово», если workflow ещё queued/in_progress.

---

## 20. Автономность

Продолжай roadmap самостоятельно.

Не задавай вопрос пользователю, если:

- решение обратимо;
- ответ есть в репозитории;
- можно выбрать безопасный default;
- можно сохранить extensibility.

Спроси только при реальном продуктовом блокере:

- требуется платный аккаунт/сертификат;
- нужен секрет или доступ;
- юридическое решение меняет продукт;
- необратимая миграция;
- две несовместимые стратегии с серьёзной стоимостью.

При отсутствии доступа не выдумывай результат. Зафиксируй точный blocker и подготовь всё, что возможно без него.

---

## 21. Ожидаемый roadmap

Следуй этапам, но корректируй после фактического аудита.

### Phase A — baseline и merge hygiene

- завершить PR #1;
- ревью и merge PR #2–#6 по порядку;
- исправить conflicts/CI;
- обновить `docs/PROJECT_STATE.md`.

### Phase B — capture durability

- chunk writer;
- recovery journal;
- storage capacity;
- AVFoundation adapter;
- filesystem integration;
- fault injection.

### Phase C — Apple vertical slice

- iOS app;
- watchOS app;
- WatchConnectivity;
- background upload;
- local library;
- playback;
- permissions;
- UI tests.

### Phase D — backend foundation

- Hono;
- auth;
- DB schema;
- R2;
- signed uploads;
- job queue;
- usage ledger;
- processing states.

### Phase E — transcription and intelligence

- faster-whisper worker;
- transcript revisions;
- evidence spans;
- structured artifacts;
- review;
- actions;
- memory candidates.

### Phase F — product hardening

- privacy;
- security;
- observability;
- quotas;
- billing;
- export/delete;
- sharing;
- App Store readiness.

### Phase G — Android

- Kotlin core semantics;
- Android phone;
- Wear OS;
- WorkManager sync;
- parity tests.

### Phase H — web and teams

- library;
- search;
- review;
- sharing;
- workspace;
- team memory;
- admin;
- billing.

---

## 22. Immediate execution directive

После первичного GitHub-аудита:

1. закончи или актуализируй PR #1;
2. проверь merge readiness PR #2–#6;
3. не ломая stack, создай:
   `foundation/chunk-writer-recovery-journal`;
4. реализуй chunk writer и recovery journal;
5. добавь unit/fault tests;
6. запусти Apple core CI;
7. запусти существующий macOS regression;
8. исправь всё до зелёного состояния;
9. открой draft PR;
10. обнови `docs/PROJECT_STATE.md` и handoff;
11. продолжи следующий PR из roadmap.

Все изменения записывай в GitHub. Не изменяй `main` напрямую. Не прекращай работу после составления плана или создания одного пустого PR.
