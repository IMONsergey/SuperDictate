# SuperDictate — Codex handoff

Дата фиксации: 2026-07-29  
Репозиторий: `IMONsergey/SuperDictate`

## 1. Что это за продукт

SuperDictate развивается из локальной macOS-диктовки в единую кроссплатформенную систему:

> быстрый и надёжный захват голоса → транскрипция → доказательная AI-структуризация → память → действия → поиск по прошлому контексту.

Это не просто диктофон, не просто speech-to-text и не уменьшенный ChatGPT на часах.

Основные платформы:

- macOS — существующее приложение;
- iOS — основное приложение, библиотека, просмотр и управление;
- watchOS — максимально быстрый захват, маркеры и офлайн-очередь;
- Android — нативный клиент;
- Wear OS — нативный wearable-клиент;
- web — библиотека, администрирование и sharing;
- Windows — более поздний этап.

Клиенты нативные:

- Apple: Swift / SwiftUI / AVFoundation / WatchConnectivity;
- Android: Kotlin / Jetpack Compose / Wear Compose;
- общий backend, OpenAPI-контракт, модели данных, продуктовые правила и processing schemas.

Flutter и React Native не являются базовой архитектурой продукта.

## 2. Текущая GitHub-структура

Все изменения выполнялись через feature-ветки и stacked draft PR. `main` напрямую не изменялся.

Отдельная базовая ветка:

- `audit/project-baseline` — PR #1, база `main`.

Основной стек:

1. `product/cross-platform-foundation` — PR #2, база `main`;
2. `foundation/apple-shared-core` — PR #3, база PR #2;
3. `product/intelligence-trust-foundation` — PR #4, база PR #3;
4. `foundation/local-first-sync-core` — PR #5, база PR #4;
5. `foundation/apple-filesystem-stores` — PR #6, база PR #5;
6. `handoff/codex-continuation` — служебная ветка с handoff-документами, база PR #6.

PR #2–#6 открыты как draft и mergeable. CI вершины PR #6 полностью зелёный:

- `Apple core` — success;
- существующий macOS `build` — success, включая self-tests, сборку bundle, codesign-проверку, installer и uninstaller.

## 3. Как начать работу в Codex

Сначала получить фактическое состояние GitHub, не полагаться только на этот документ.

Рекомендуемый порядок:

```bash
git fetch --all --prune
git switch handoff/codex-continuation
git pull --ff-only
```

Прочитать:

- `docs/CODEX_MASTER_PROMPT.md`;
- этот файл;
- документы из раздела 5;
- код `packages/apple-core`;
- контракт `packages/api-contract/openapi.yaml`;
- состояние PR #1–#6 и GitHub Actions.

После чтения переключиться на вершину рабочего стека:

```bash
git switch foundation/apple-filesystem-stores
git pull --ff-only
git switch -c foundation/chunk-writer-recovery-journal
```

Не писать новый runtime-код непосредственно в `handoff/codex-continuation`.

## 4. Текущее техническое состояние

### Существующее macOS-приложение

Текущий runtime остаётся рабочим. Это локальная macOS-диктовка на Swift с AVFoundation и FluidAudio/Parakeet. Нельзя ломать:

- текущую локальную транскрипцию;
- разрешения микрофона;
- Accessibility / Input Monitoring;
- горячие клавиши;
- историю;
- существующие пути данных;
- update/install/uninstall flow;
- Direct build;
- будущую App Store-совместимость.

### Общий Apple core

Путь:

```text
packages/apple-core
```

Уже реализовано:

- Swift 6 package;
- macOS 14+, iOS 17+, watchOS 10+;
- recording modes;
- source platforms;
- markers;
- recording descriptor;
- recording lifecycle state machine;
- processing and retry boundaries;
- product policies;
- sensitivity, consent, retention, memory scope;
- evidence-backed intelligence models;
- local-first manifests;
- immutable audio chunk models;
- acknowledgement levels;
- idempotent upload queue;
- exponential backoff;
- upload coordinator;
- JSON filesystem manifest store;
- JSON filesystem queue store;
- unit and async tests;
- отдельный Apple core CI.

### API contract

Путь:

```text
packages/api-contract/openapi.yaml
```

Контракт содержит базовые операции:

- создание записи;
- получение upload intent;
- завершение загрузки;
- получение статуса обработки;
- маркеры важных моментов.

Контракт пока foundation-level. Его нужно расширять эволюционно, сохраняя обратную совместимость или вводя версионирование.

## 5. Файлы, добавленные в ходе проектирования и разработки

### PR #1

- `docs/PROJECT_STATE.md`

### PR #2

- `.github/workflows/api-contract.yml`
- `docs/CROSS_PLATFORM_PRODUCT.md`
- `docs/CROSS_PLATFORM_ROADMAP.md`
- `docs/adr/0001-native-clients-shared-contract.md`
- `packages/api-contract/openapi.yaml`

### PR #3

- `.github/workflows/apple-core.yml`
- `packages/apple-core/Package.swift`
- `packages/apple-core/README.md`
- `packages/apple-core/Sources/SuperDictateCore/RecordingModels.swift`
- `packages/apple-core/Sources/SuperDictateCore/RecordingStateMachine.swift`
- `packages/apple-core/Tests/SuperDictateCoreTests/RecordingStateMachineTests.swift`

### PR #4

- `docs/AI_MEMORY_AND_ACTIONS.md`
- `docs/PACKAGING_USAGE_AND_ECONOMICS.md`
- `docs/PRODUCT_METRICS_AND_EVALUATION.md`
- `docs/PRODUCT_OPERATING_SYSTEM.md`
- `docs/TRUST_PRIVACY_SECURITY.md`
- `docs/WATCH_CAPTURE_UX_SPEC.md`
- `packages/apple-core/Sources/SuperDictateCore/IntelligenceModels.swift`
- `packages/apple-core/Sources/SuperDictateCore/ProductPolicies.swift`
- `packages/apple-core/Tests/SuperDictateCoreTests/ProductSemanticsTests.swift`

### PR #5

- `docs/LOCAL_FIRST_SYNC_PROTOCOL.md`
- `packages/apple-core/Sources/SuperDictateCore/LocalFirstSyncModels.swift`
- `packages/apple-core/Sources/SuperDictateCore/UploadQueueCoordinator.swift`
- `packages/apple-core/Tests/SuperDictateCoreTests/LocalFirstSyncTests.swift`
- `packages/apple-core/Tests/SuperDictateCoreTests/UploadQueueCoordinatorTests.swift`

### PR #6

- `packages/apple-core/Sources/SuperDictateCore/AppleFileSystemStores.swift`
- `packages/apple-core/Tests/SuperDictateCoreTests/AppleFileSystemStoreTests.swift`

### Handoff

- `docs/CODEX_HANDOFF.md`
- `docs/CODEX_MASTER_PROMPT.md`

## 6. Неприкосновенные продуктовые инварианты

1. Запись всегда local-first.
2. Потеря сети не должна прерывать или уничтожать запись.
3. Закрытый audio chunk неизменяем.
4. Один `clientRecordingID` сохраняется на всех устройствах и во всех retry.
5. Одинаковая операция не должна создавать дубликаты.
6. Состояние очереди фиксируется до сетевого вызова.
7. Source transcript, отредактированный transcript и AI interpretation — разные слои.
8. Решения, задачи, обязательства и память требуют provenance.
9. AI не назначает владельца или срок как факт без прямого evidence.
10. Memory candidate не становится trusted memory молча.
11. Нет скрытого режима записи.
12. Индикация записи должна быть явной.
13. Квота облака может остановить обработку, но не локальный capture.
14. Пользователь всегда может экспортировать, исправлять и удалять свои данные.
15. Удаление аудио, transcript, derived artifacts и memory должно быть управляемым и раздельным.
16. Часы — поверхность захвата, а не уменьшенный телефон.
17. Существующий macOS runtime нельзя ломать при миграции.
18. Безлимит на старте не обещать: usage должен измеряться и ограничиваться прозрачно.

## 7. Следующий рекомендуемый PR

Ветка:

```text
foundation/chunk-writer-recovery-journal
```

База:

```text
foundation/apple-filesystem-stores
```

Задача:

- реализовать реальную запись immutable audio chunks на filesystem;
- вести recovery journal;
- атомарно обновлять manifest;
- восстанавливать незавершённую сессию после crash/kill/power loss;
- проверять checksum;
- не считать chunk закрытым до flush/fsync/close;
- уметь отличать полный, частично записанный и повреждённый chunk;
- покрыть fault-injection тестами.

После этого:

1. AVFoundation capture adapter для iOS/watchOS;
2. iPhone local-first vertical slice;
3. watchOS capture vertical slice;
4. WatchConnectivity transport;
5. signed object-storage transport;
6. backend skeleton;
7. transcription worker;
8. evidence-aware processing;
9. Android/Wear OS parity.

## 8. Команды проверки

Минимум:

```bash
swift test --package-path packages/apple-core
bash -n install.sh uninstall.sh scripts/build-app.sh
plutil -lint swift/Info.plist entitlements.plist
swift run -c debug --package-path swift Parakey --self-test all
./scripts/build-app.sh ./dist/SuperDictate.app
codesign --verify --deep --strict ./dist/SuperDictate.app
```

Для API:

```bash
# использовать команду из .github/workflows/api-contract.yml
```

Не снижать строгость CI, чтобы скрыть проблему. Исправлять причину.

## 9. Стиль работы

- не менять `main` напрямую;
- одна содержательная задача — одна ветка и один PR;
- stacked PR допустимы;
- коммиты небольшие и осмысленные;
- тесты добавляются вместе с логикой;
- PR содержит summary, risks, validation, migrations, privacy impact и rollback;
- не заявлять успех без фактической проверки;
- не спрашивать пользователя о мелких технических решениях;
- при неоднозначности выбирать безопасный и обратимый вариант;
- фиксировать каждое архитектурное решение в ADR или соответствующем документе;
- обновлять этот handoff после существенного этапа.

## 10. Что считать первым полноценным milestone

Первый end-to-end milestone завершён, когда:

1. iPhone начинает запись одним действием;
2. запись режется на crash-safe chunks;
3. состояние переживает принудительное завершение приложения;
4. запись отображается в локальной библиотеке;
5. загрузка идёт resumable и idempotent;
6. сервер принимает запись;
7. транскриптор возвращает transcript;
8. processing возвращает summary, tasks, decisions и evidence spans;
9. результат отображается на iPhone;
10. Apple Watch может инициировать capture, поставить маркер и передать запись;
11. офлайн-сценарий работает;
12. удаление и экспорт работают;
13. весь путь покрыт логами, метриками и тестами;
14. существующий macOS runtime остаётся зелёным.
