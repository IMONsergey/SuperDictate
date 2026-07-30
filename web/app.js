"use strict";

window.__superdictateErrors = [];
window.addEventListener("error", (event) => {
  window.__superdictateErrors.push(event.message || String(event.error || "error"));
});
window.addEventListener("unhandledrejection", (event) => {
  window.__superdictateErrors.push(event.reason?.message || String(event.reason || "unhandled rejection"));
});

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const elements = {
  runtimeLine: $("#runtimeLine"),
  runtimeDot: $("#runtimeDot"),
  runtimeStatus: $("#runtimeStatus"),
  globalSearch: $("#globalSearch"),
  modelSelect: $("#modelSelect"),
  demoBtn: $("#demoBtn"),
  exportBtn: $("#exportBtn"),
  pipeline: $("#pipeline"),
  pipelineExport: $("#pipelineExport"),
  navList: $("#navList"),
  stepRecord: $("#stepRecord"),
  stepTranscript: $("#stepTranscript"),
  stepSummary: $("#stepSummary"),
  stepTasks: $("#stepTasks"),
  stepExport: $("#stepExport"),
  activeModeLabel: $("#activeModeLabel"),
  modeGrid: $("#modeGrid"),
  sessionState: $("#sessionState"),
  chunkCount: $("#chunkCount"),
  markerCount: $("#markerCount"),
  byteCount: $("#byteCount"),
  recoveryState: $("#recoveryState"),
  markerTitle: $("#markerTitle"),
  markerList: $("#markerList"),
  timer: $("#timer"),
  recorderSubtitle: $("#recorderSubtitle"),
  recordingBadge: $("#recordingBadge"),
  waveCanvas: $("#waveCanvas"),
  levelFill: $("#levelFill"),
  waveFooter: $("#waveFooter"),
  recordBtn: $("#recordBtn"),
  pauseBtn: $("#pauseBtn"),
  markerBtn: $("#markerBtn"),
  stopBtn: $("#stopBtn"),
  transcriptStatus: $("#transcriptStatus"),
  transcriptInput: $("#transcriptInput"),
  browserSpeechBtn: $("#browserSpeechBtn"),
  sampleTextBtn: $("#sampleTextBtn"),
  processTextBtn: $("#processTextBtn"),
  clearTextBtn: $("#clearTextBtn"),
  copyTranscriptBtn: $("#copyTranscriptBtn"),
  summaryStatus: $("#summaryStatus"),
  summaryText: $("#summaryText"),
  copySummaryBtn: $("#copySummaryBtn"),
  summaryToTasksBtn: $("#summaryToTasksBtn"),
  decisionList: $("#decisionList"),
  riskList: $("#riskList"),
  taskStatus: $("#taskStatus"),
  addTaskBtn: $("#addTaskBtn"),
  copyTasksBtn: $("#copyTasksBtn"),
  taskList: $("#taskList"),
  chunkWindowSelect: $("#chunkWindowSelect"),
  selectedModelLabel: $("#selectedModelLabel"),
  modelList: $("#modelList"),
  cafLabel: $("#cafLabel"),
  chunkList: $("#chunkList"),
  journalState: $("#journalState"),
  journalView: $("#journalView"),
  crashBtn: $("#crashBtn"),
  recoverBtn: $("#recoverBtn"),
  exportPreview: $("#exportPreview"),
  copyPackageBtn: $("#copyPackageBtn"),
  downloadMarkdownBtn: $("#downloadMarkdownBtn"),
  sourceCard: $("#sourceCard"),
  modelCard: $("#modelCard"),
  packageCard: $("#packageCard"),
  startTodayBtn: $("#startTodayBtn"),
  openTranscriptBtn: $("#openTranscriptBtn"),
  openReviewBtn: $("#openReviewBtn"),
  modelRecommendation: $("#modelRecommendation"),
  processingStateList: $("#processingStateList"),
  calendarQueue: $("#calendarQueue"),
  libraryList: $("#libraryList"),
  evidenceList: $("#evidenceList"),
  mindMap: $("#mindMap"),
  askScopeList: $("#askScopeList"),
  askInput: $("#askInput"),
  askRunBtn: $("#askRunBtn"),
  askAnswer: $("#askAnswer"),
  peopleList: $("#peopleList"),
};

const STORAGE_KEY = "superdictate.web.workbench.v3";
const DB_NAME = "superdictate-web-workbench";
const DB_VERSION = 1;
const CHUNK_STORE = "chunks";

const modelCatalog = [
  {
    id: "whisper_cpp_small",
    title: "Whisper.cpp Small",
    shortTitle: "Whisper.cpp Small",
    subtitle: "Рекомендовано для Intel preview: лучший баланс качества, скорости и веса.",
    status: "выбрана",
    tags: ["Intel", "RU/EN", "~466 MB"],
  },
  {
    id: "whisper_cpp_base",
    title: "Whisper.cpp Base",
    shortTitle: "Whisper.cpp Base",
    subtitle: "Самый легкий Intel fallback, если Small слишком медленная на CPU.",
    status: "fallback",
    tags: ["Intel", "быстрее", "~150 MB"],
  },
  {
    id: "whisper_cpp_medium",
    title: "Whisper.cpp Medium",
    shortTitle: "Whisper.cpp Medium",
    subtitle: "Более точная локальная модель для длинных встреч, когда latency приемлема.",
    status: "качество",
    tags: ["Intel", "медленнее", "~1.5 GB"],
  },
  {
    id: "parakeet_tdt_v3",
    title: "Parakeet TDT v3",
    shortTitle: "Parakeet TDT v3",
    subtitle: "Apple Silicon: FluidAudio, CoreML, ANE.",
    status: "нативная",
    tags: ["M1+", "offline", "~700 MB"],
  },
  {
    id: "local_summarizer",
    title: "Local summarizer",
    shortTitle: "Local summarizer",
    subtitle: "Следующий локальный AI слой для выжимок, задач и памяти.",
    status: "план",
    tags: ["выжимки", "задачи"],
  },
];

const sampleTranscript = `Решили делать SuperDictate как app-only альтернативу Pocket: запись с Mac, iPhone, Android и часов без отдельного устройства. Action item: сначала переделать первый экран в Today, Capture, Library, AI Review, Tasks, Ask и Models. Решение: для Intel preview ставим Whisper.cpp Small, потому что это бесплатная локальная модель с нормальным балансом качества и скорости. Риск: интерфейс не должен обещать cloud magic, если сейчас работает browser preview и будущий native whisper.cpp backend. Нужно показывать evidence у задач, делать кнопку календаря и дать пользователю спросить текущую запись. Договорились после web preview допилить native Intel transcription runtime и модельный менеджер.`;

const state = {
  sessionId: crypto.randomUUID(),
  mode: "Dictation",
  status: "idle",
  activeTab: "today",
  selectedModel: "whisper_cpp_small",
  askScope: "recording",
  askQuestion: "",
  askAnswer: "",
  chunkWindowSec: 5,
  chunks: [],
  markers: [],
  transcript: "",
  summary: "",
  actions: [],
  decisions: [],
  risks: [],
  startedAt: 0,
  pausedAt: 0,
  pausedMs: 0,
  stream: null,
  recorder: null,
  audioContext: null,
  analyser: null,
  animationFrame: 0,
  timerInterval: 0,
  speechRecognition: null,
  speechActive: false,
  levelHistory: Array.from({ length: 180 }, () => 0),
};

function hydrate() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return;

  try {
    const saved = JSON.parse(raw);
    for (const key of [
      "sessionId",
      "mode",
      "status",
      "activeTab",
      "selectedModel",
      "askScope",
      "askQuestion",
      "askAnswer",
      "chunkWindowSec",
      "chunks",
      "markers",
      "transcript",
      "summary",
      "actions",
      "decisions",
      "risks",
    ]) {
      if (saved[key] !== undefined) state[key] = saved[key];
    }
  } catch {
    localStorage.removeItem(STORAGE_KEY);
  }
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    sessionId: state.sessionId,
    mode: state.mode,
    status: state.status === "recording" || state.status === "paused" ? "recoverable" : state.status,
    activeTab: state.activeTab,
    selectedModel: state.selectedModel,
    askScope: state.askScope,
    askQuestion: state.askQuestion,
    askAnswer: state.askAnswer,
    chunkWindowSec: state.chunkWindowSec,
    chunks: state.chunks.map(serializableChunk),
    markers: state.markers,
    transcript: state.transcript,
    summary: state.summary,
    actions: state.actions,
    decisions: state.decisions,
    risks: state.risks,
  }));
}

function serializableChunk(chunk) {
  return {
    id: chunk.id,
    sequence: chunk.sequence,
    state: chunk.state,
    bytes: chunk.bytes,
    durationMs: chunk.durationMs,
    checksum: chunk.checksum,
    mimeType: chunk.mimeType,
    createdAt: chunk.createdAt,
  };
}

function openDB() {
  return new Promise((resolve, reject) => {
    if (!("indexedDB" in window)) {
      reject(new Error("IndexedDB unavailable"));
      return;
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(CHUNK_STORE)) {
        const store = db.createObjectStore(CHUNK_STORE, { keyPath: "id" });
        store.createIndex("sessionId", "sessionId", { unique: false });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function saveChunkBlob(chunk, blob) {
  try {
    const db = await openDB();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(CHUNK_STORE, "readwrite");
      tx.objectStore(CHUNK_STORE).put({ ...serializableChunk(chunk), sessionId: state.sessionId, blob });
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch (error) {
    console.warn("Chunk persistence failed", error);
  }
}

async function loadStoredChunks() {
  try {
    const db = await openDB();
    const chunks = await new Promise((resolve, reject) => {
      const tx = db.transaction(CHUNK_STORE, "readonly");
      const request = tx.objectStore(CHUNK_STORE).index("sessionId").getAll(state.sessionId);
      request.onsuccess = () => resolve(request.result || []);
      request.onerror = () => reject(request.error);
    });
    db.close();
    return chunks.map(serializableChunk).sort((a, b) => a.sequence - b.sequence);
  } catch {
    return [];
  }
}

function setStatus(status, label) {
  state.status = status;
  const labels = {
    idle: "Готово",
    ready: "Готово",
    recording: "Запись",
    paused: "Пауза",
    processing: "Обработка",
    crashed: "Сбой",
    recovered: "Восстановлено",
    recoverable: "Можно восстановить",
  };
  elements.runtimeStatus.textContent = label || labels[status] || status;
  elements.sessionState.textContent = labels[status] || status;
  elements.recordingBadge.textContent = labels[status] || status;
  elements.recordingBadge.classList.toggle("recording", status === "recording");
  elements.recordingBadge.classList.toggle("processing", status === "processing" || status === "paused");
  elements.runtimeDot.style.background = status === "crashed" ? "var(--red)" : status === "recording" ? "var(--amber)" : "var(--green)";
  elements.recoveryState.textContent = status === "crashed" || status === "recoverable" ? "Нужно восстановить" : "Чисто";
  elements.journalState.textContent = elements.recoveryState.textContent;
  persist();
  render();
}

function render() {
  renderModelControls();
  renderPipeline();
  renderSession();
  renderPanels();
  renderResults();
  renderWorkbench();
  renderExport();
}

function renderModelControls() {
  const selected = selectedModel();
  elements.runtimeLine.textContent = `Conversation memory OS · ${selected.shortTitle}`;
  elements.selectedModelLabel.textContent = selected.shortTitle;
  if (elements.modelRecommendation) {
    elements.modelRecommendation.textContent = `${selected.shortTitle}: ${selected.subtitle}`;
  }

  elements.modelSelect.innerHTML = modelCatalog
    .filter((model) => model.id !== "local_summarizer")
    .map((model) => `<option value="${model.id}">${escapeHtml(model.shortTitle)}</option>`)
    .join("");
  elements.modelSelect.value = state.selectedModel;

  if (!elements.modelList) return;
  elements.modelList.innerHTML = "";
  for (const model of modelCatalog) {
    const card = document.createElement("article");
    const selectable = model.id !== "local_summarizer";
    card.className = `model-card${model.id === state.selectedModel ? " active" : ""}${selectable ? "" : " disabled"}`;
    card.innerHTML = `
      <h3>${escapeHtml(model.title)}</h3>
      <p>${escapeHtml(model.subtitle)}</p>
      <div class="model-meta">
        <span class="pill">${escapeHtml(model.status)}</span>
        ${model.tags.map((tag) => `<span class="pill">${escapeHtml(tag)}</span>`).join("")}
        <span class="pill good">${model.id.startsWith("whisper_cpp") ? "free OSS" : "local"}</span>
      </div>
      <button class="button ${model.id === state.selectedModel ? "primary-text" : "ghost"}" type="button">
        ${model.id === state.selectedModel ? "Используется" : selectable ? "Выбрать" : "Скоро"}
      </button>
    `;
    if (selectable) {
      card.addEventListener("click", () => {
        state.selectedModel = model.id;
        persist();
        render();
      });
    }
    elements.modelList.appendChild(card);
  }
}

function renderPipeline() {
  $$(".pipeline-step[data-tab]").forEach((button) => {
    const tab = button.dataset.tab;
    button.classList.toggle("active", state.activeTab === tab);
    button.classList.toggle("complete", stepComplete(tab));
    button.classList.toggle("warn", tab === "transcript" && state.chunks.length > 0 && !state.transcript.trim());
  });
  elements.stepRecord.textContent = state.chunks.length ? fragmentLabel(state.chunks.length) : "микрофон готов";
  elements.stepTranscript.textContent = state.transcript.trim() ? `${wordCount(state.transcript)} слов` : "текст пуст";
  elements.stepSummary.textContent = state.summary ? "готов" : "не создан";
  elements.stepTasks.textContent = taskLabel(state.actions.length);
  if (elements.stepExport) {
    elements.stepExport.textContent = exportReady() ? "можно скачать" : "нет данных";
  }
  if (elements.navList) {
    $$(".nav-item[data-tab]").forEach((button) => {
      button.classList.toggle("active", state.activeTab === button.dataset.tab);
    });
  }
}

function stepComplete(tab) {
  if (tab === "recorder") return state.chunks.length > 0;
  if (tab === "transcript") return state.transcript.trim().length > 0;
  if (tab === "summary") return Boolean(state.summary);
  if (tab === "tasks") return state.actions.length > 0;
  if (tab === "export") return exportReady();
  return false;
}

function renderSession() {
  const modeLabels = {
    Meeting: "Встреча",
    Discovery: "Discovery",
    Thought: "Мысль",
    Dictation: "Диктовка",
    Interview: "Интервью",
    Lecture: "Лекция",
    Daily: "Daily memory",
  };
  elements.activeModeLabel.textContent = modeLabels[state.mode] || state.mode;
  $$(".mode-row").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === state.mode);
  });
  elements.chunkCount.textContent = String(state.chunks.length);
  elements.markerCount.textContent = String(state.markers.length);
  elements.markerTitle.textContent = state.markers.length ? String(state.markers.length) : "нет";
  elements.byteCount.textContent = formatBytes(state.chunks.reduce((sum, chunk) => sum + chunk.bytes, 0));
  elements.chunkWindowSelect.value = String(state.chunkWindowSec);
  elements.cafLabel.textContent = `${state.chunkWindowSec} сек`;
  elements.transcriptInput.value = state.transcript;
  elements.transcriptStatus.textContent = transcriptStatusText();
  elements.summaryStatus.textContent = state.summary ? "AI Review создан локально в preview." : "Добавьте текст и запустите AI Review.";
  elements.taskStatus.textContent = state.actions.length ? `${taskLabel(state.actions.length)} · ${scheduledTaskCount()} в календаре` : "Задачи появятся после выжимки.";
  if (elements.sourceCard) {
    elements.sourceCard.textContent = state.transcript.trim() ? `${wordCount(state.transcript)} слов в тексте` : "микрофон или текстовый ввод";
  }
  if (elements.modelCard) {
    elements.modelCard.textContent = `${selectedModel().shortTitle} выбрана`;
  }
  if (elements.packageCard) {
    elements.packageCard.textContent = `${fragmentLabel(state.chunks.length)} · ${elements.recoveryState.textContent.toLowerCase()}`;
  }
  if (elements.askInput && document.activeElement !== elements.askInput) {
    elements.askInput.value = state.askQuestion;
  }
  if (elements.askAnswer) {
    elements.askAnswer.textContent = state.askAnswer || "Задайте вопрос после демо или вставки transcript.";
  }
  if (elements.askScopeList) {
    $$(".scope-chip[data-scope]").forEach((button) => {
      button.classList.toggle("active", button.dataset.scope === state.askScope);
    });
  }
}

function transcriptStatusText() {
  if (state.transcript.trim()) return "Транскрипт готов к обработке.";
  if (state.chunks.length) return "Аудио сохранено. Native Intel распознает его через whisper.cpp; в web preview добавьте текст или нажмите «Пример».";
  return "Добавьте текст вручную, включите браузерную речь или демо-проход.";
}

function renderPanels() {
  renderMarkers();
  renderChunks();
  renderJournal();
}

function renderMarkers() {
  if (!state.markers.length) {
    elements.markerList.textContent = "Пусто";
    return;
  }
  elements.markerList.innerHTML = "";
  for (const marker of state.markers) {
    const item = document.createElement("div");
    item.className = "marker-item";
    item.innerHTML = `<strong>${escapeHtml(marker.label)}</strong><span>${formatDuration(marker.offsetMs)}</span>`;
    elements.markerList.appendChild(item);
  }
}

function renderChunks() {
  if (!state.chunks.length) {
    elements.chunkList.textContent = "Нет фрагментов";
    elements.waveFooter.textContent = "Нет аудио";
    return;
  }
  elements.chunkList.innerHTML = "";
  for (const chunk of [...state.chunks].sort((a, b) => b.sequence - a.sequence)) {
    const item = document.createElement("div");
    item.className = "chunk-item";
    item.innerHTML = `
      <strong>Фрагмент ${String(chunk.sequence + 1).padStart(3, "0")}</strong>
      <span>${formatDuration(chunk.durationMs)} · ${formatBytes(chunk.bytes)} · ${chunk.checksum.slice(0, 18)}</span>
    `;
    elements.chunkList.appendChild(item);
  }
  elements.waveFooter.textContent = `${fragmentLabel(state.chunks.length)} сохранено`;
}

function renderJournal() {
  elements.journalView.textContent = JSON.stringify({
    session_id: state.sessionId,
    mode: state.mode.toLowerCase(),
    state: state.status,
    selected_model: state.selectedModel,
    chunk_window_sec: state.chunkWindowSec,
    chunks: state.chunks.map((chunk) => ({
      sequence: chunk.sequence,
      state: chunk.state,
      bytes: chunk.bytes,
      duration_ms: chunk.durationMs,
      checksum: chunk.checksum,
    })),
    markers: state.markers.map((marker) => ({
      label: marker.label,
      offset_ms: marker.offsetMs,
    })),
  }, null, 2);
}

function renderResults() {
  elements.summaryText.textContent = state.summary || "Пока нет выжимки.";
  renderList(elements.decisionList, state.decisions, "Пока нет решений.");
  renderList(elements.riskList, state.risks, "Пока нет рисков.");
  renderTasks();
}

function renderExport() {
  if (!elements.exportPreview) return;
  elements.exportPreview.textContent = exportPackageText();
}

function renderWorkbench() {
  renderProcessingState();
  renderCalendarQueue();
  renderLibrary();
  renderEvidence();
  renderMindMap();
  renderPeople();
}

function renderProcessingState() {
  if (!elements.processingStateList) return;
  const states = [
    ["Saved locally", state.chunks.length > 0 || state.transcript.trim(), state.status === "recording"],
    ["Transcript ready", state.transcript.trim(), false],
    ["AI Review ready", state.summary, state.status === "processing"],
    ["Tasks extracted", state.actions.length > 0, false],
    ["Memory indexed", state.summary && state.actions.length > 0, false],
  ];
  elements.processingStateList.innerHTML = "";
  for (const [title, complete, active] of states) {
    const item = document.createElement("div");
    item.className = `state-item${complete ? " complete" : ""}${active ? " active" : ""}`;
    item.innerHTML = `
      <span class="state-dot"></span>
      <strong>${escapeHtml(title)}</strong>
      <span>${complete ? "done" : active ? "active" : "waiting"}</span>
    `;
    elements.processingStateList.appendChild(item);
  }
}

function renderCalendarQueue() {
  if (!elements.calendarQueue) return;
  elements.calendarQueue.innerHTML = "";
  const unscheduled = state.actions.filter((task) => !task.calendarState);
  if (!state.actions.length) {
    elements.calendarQueue.appendChild(emptyItem("calendar-item", "Нет задач для календаря. Запустите демо или AI Review."));
    return;
  }
  for (const task of state.actions.slice(0, 5)) {
    const item = document.createElement("article");
    item.className = "calendar-item";
    item.innerHTML = `
      <strong>${escapeHtml(task.title)}</strong>
      <span>${task.calendarState ? "Запланировано" : "Нужно назначить время"} · ${escapeHtml(task.evidence || task.source)}</span>
    `;
    elements.calendarQueue.appendChild(item);
  }
  if (unscheduled.length) {
    const item = document.createElement("article");
    item.className = "calendar-item";
    item.innerHTML = `<strong>Day One rule</strong><span>${taskLabel(unscheduled.length)} еще без времени.</span>`;
    elements.calendarQueue.appendChild(item);
  }
}

function renderLibrary() {
  if (!elements.libraryList) return;
  elements.libraryList.innerHTML = "";
  if (!exportReady()) {
    elements.libraryList.appendChild(emptyItem("library-item", "Пока нет записи. Нажмите «Демо» или начните capture."));
    return;
  }

  const item = document.createElement("article");
  item.className = "library-item";
  item.innerHTML = `
    <strong>${escapeHtml(modeLabel())} · текущая сессия</strong>
    <span>${state.summary ? "AI Review ready" : state.transcript.trim() ? "Transcript ready" : "Audio saved"} · ${fragmentLabel(state.chunks.length)} · ${wordCount(state.transcript)} слов</span>
    <div class="pill-row">
      <span class="pill good">${escapeHtml(selectedModel().shortTitle)}</span>
      <span class="pill">${taskLabel(state.actions.length)}</span>
      <span class="pill">${state.markers.length} меток</span>
    </div>
  `;
  elements.libraryList.appendChild(item);

  for (const marker of state.markers.slice(0, 4)) {
    const markerItem = document.createElement("article");
    markerItem.className = "library-item";
    markerItem.innerHTML = `<strong>${escapeHtml(marker.label)}</strong><span>важный момент · ${formatDuration(marker.offsetMs)}</span>`;
    elements.libraryList.appendChild(markerItem);
  }
}

function renderEvidence() {
  if (!elements.evidenceList) return;
  elements.evidenceList.innerHTML = "";
  const sources = [
    ...state.decisions.map((text, index) => ({ kind: "decision", text, at: index + 1 })),
    ...state.risks.map((text, index) => ({ kind: "risk", text, at: index + 1 })),
    ...state.actions.map((task, index) => ({ kind: "task", text: task.source, at: index + 1 })),
  ].slice(0, 7);

  if (!sources.length) {
    elements.evidenceList.appendChild(emptyItem("evidence-item", "Evidence появится после AI Review."));
    return;
  }

  for (const source of sources) {
    const item = document.createElement("article");
    item.className = "evidence-item";
    item.innerHTML = `
      <strong>${escapeHtml(source.kind)} · T+${String(source.at).padStart(2, "0")}:00</strong>
      <span>${escapeHtml(source.text)}</span>
    `;
    elements.evidenceList.appendChild(item);
  }
}

function renderMindMap() {
  if (!elements.mindMap) return;
  elements.mindMap.innerHTML = "";
  if (!state.summary) {
    elements.mindMap.appendChild(emptyItem("mind-node", "Mind map появится после AI Review."));
    return;
  }

  const nodes = [
    ["root", modeLabel()],
    ["", state.decisions[0] || "Решения не найдены"],
    ["", state.risks[0] || "Риски не найдены"],
    ["", state.actions[0]?.title || "Задачи не найдены"],
  ];
  for (const [tone, text] of nodes) {
    const node = document.createElement("div");
    node.className = `mind-node${tone ? ` ${tone}` : ""}`;
    node.textContent = text;
    elements.mindMap.appendChild(node);
  }
}

function renderPeople() {
  if (!elements.peopleList) return;
  elements.peopleList.innerHTML = "";
  const people = inferPeople();
  if (!people.length) {
    elements.peopleList.appendChild(emptyItem("person-card", "Спикеры появятся после diarization/runtime. Preview показывает ручную модель будущей people library."));
    return;
  }
  for (const person of people) {
    const item = document.createElement("article");
    item.className = "person-card";
    item.innerHTML = `
      <strong>${escapeHtml(person.name)}</strong>
      <span>${escapeHtml(person.role)} · ${person.count} упоминаний · можно связать с задачами и встречами</span>
    `;
    elements.peopleList.appendChild(item);
  }
}

function renderList(list, items, emptyText) {
  list.innerHTML = "";
  const source = items.length ? items : [emptyText];
  for (const item of source) {
    const li = document.createElement("li");
    li.textContent = item;
    list.appendChild(li);
  }
}

function renderTasks() {
  elements.taskList.innerHTML = "";
  if (!state.actions.length) {
    const empty = document.createElement("div");
    empty.className = "result-block";
    empty.textContent = "Пока нет задач.";
    elements.taskList.appendChild(empty);
    return;
  }

  state.actions.forEach((task, index) => {
    const item = document.createElement("article");
    item.className = `task-item${task.done ? " done" : ""}`;
    item.innerHTML = `
      <input type="checkbox" ${task.done ? "checked" : ""} aria-label="Готово">
      <div>
        <strong>${escapeHtml(task.title)}</strong>
        <p>${escapeHtml(task.evidence || task.source)}</p>
        <div class="task-footer">
          <span class="pill ${task.calendarState ? "good" : "warn"}">${task.calendarState ? "в календаре" : "без времени"}</span>
          <span class="pill">${escapeHtml(task.owner || "owner: not stated")}</span>
          <button class="button ghost" type="button" data-schedule="${index}">${task.calendarState ? "Переназначить" : "В календарь"}</button>
        </div>
      </div>
      <span class="task-priority">${escapeHtml(task.priority)}</span>
    `;
    item.querySelector("input").addEventListener("change", (event) => {
      state.actions[index].done = event.target.checked;
      persist();
      render();
    });
    item.querySelector("[data-schedule]").addEventListener("click", () => scheduleTask(index));
    elements.taskList.appendChild(item);
  });
}

function emptyItem(className, text) {
  const item = document.createElement("article");
  item.className = `${className} empty`;
  item.textContent = text;
  return item;
}

async function startRecording() {
  if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) {
    alert("Браузер не дал доступ к записи аудио. Открой preview в Chrome или Safari 17+.");
    return;
  }

  state.stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  });

  state.sessionId = crypto.randomUUID();
  state.chunks = [];
  state.markers = [];
  state.startedAt = Date.now();
  state.pausedAt = 0;
  state.pausedMs = 0;
  setupAnalyser(state.stream);

  state.recorder = new MediaRecorder(state.stream, preferredRecorderOptions());
  state.recorder.ondataavailable = handleRecorderData;
  state.recorder.onstop = completeRecording;
  state.recorder.start(state.chunkWindowSec * 1000);

  elements.recordBtn.disabled = true;
  elements.pauseBtn.disabled = false;
  elements.markerBtn.disabled = false;
  elements.stopBtn.disabled = false;
  elements.pauseBtn.textContent = "Пауза";
  elements.recorderSubtitle.textContent = `${modeLabel()} · запись идет`;
  state.timerInterval = window.setInterval(updateTimer, 250);
  setStatus("recording");
  drawWaveform();
}

function preferredRecorderOptions() {
  for (const mimeType of ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"]) {
    if (MediaRecorder.isTypeSupported(mimeType)) return { mimeType };
  }
  return {};
}

async function handleRecorderData(event) {
  if (!event.data || event.data.size === 0) return;

  const buffer = await event.data.arrayBuffer();
  const checksum = await sha256(buffer);
  const elapsedMs = Math.max(1, currentElapsedMs());
  const sequence = state.chunks.length;
  const chunk = {
    id: `${state.sessionId}-${sequence}`,
    sequence,
    state: "verified",
    bytes: event.data.size,
    durationMs: Math.max(1, Math.min(state.chunkWindowSec * 1000, elapsedMs - sequence * state.chunkWindowSec * 1000)),
    checksum,
    mimeType: event.data.type || "audio",
    createdAt: new Date().toISOString(),
  };
  state.chunks.push(chunk);
  await saveChunkBlob(chunk, event.data);
  persist();
  render();
}

function pauseRecording() {
  if (!state.recorder) return;
  if (state.recorder.state === "recording") {
    state.recorder.requestData();
    state.recorder.pause();
    state.pausedAt = Date.now();
    elements.pauseBtn.textContent = "Продолжить";
    setStatus("paused");
    return;
  }
  if (state.recorder.state === "paused") {
    state.pausedMs += Date.now() - state.pausedAt;
    state.pausedAt = 0;
    state.recorder.resume();
    elements.pauseBtn.textContent = "Пауза";
    setStatus("recording");
  }
}

function stopRecording() {
  if (!state.recorder) return;
  if (state.recorder.state !== "inactive") {
    state.recorder.requestData();
    state.recorder.stop();
  }
}

function completeRecording() {
  teardownMedia();
  elements.recordBtn.disabled = false;
  elements.pauseBtn.disabled = true;
  elements.markerBtn.disabled = true;
  elements.stopBtn.disabled = true;
  elements.pauseBtn.textContent = "Пауза";
  elements.recorderSubtitle.textContent = state.chunks.length
    ? "Аудио сохранено локально."
    : "Запись остановлена до создания фрагмента.";
  setStatus("ready");
  switchTab("transcript");
}

function addMarker() {
  state.markers.push({
    label: `Метка ${String(state.markers.length + 1).padStart(2, "0")}`,
    offsetMs: currentElapsedMs(),
  });
  persist();
  render();
}

function setupAnalyser(stream) {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return;
  state.audioContext = new AudioContextClass();
  state.analyser = state.audioContext.createAnalyser();
  state.analyser.fftSize = 1024;
  state.audioContext.createMediaStreamSource(stream).connect(state.analyser);
}

function teardownMedia() {
  window.clearInterval(state.timerInterval);
  window.cancelAnimationFrame(state.animationFrame);
  state.timerInterval = 0;
  state.animationFrame = 0;
  state.recorder = null;
  if (state.stream) {
    for (const track of state.stream.getTracks()) track.stop();
  }
  state.stream = null;
  if (state.audioContext) state.audioContext.close().catch(() => {});
  state.audioContext = null;
  state.analyser = null;
  state.levelHistory = state.levelHistory.map(() => 0);
  elements.levelFill.style.width = "0%";
  updateTimer(true);
  drawIdleWaveform();
}

function drawWaveform() {
  const canvas = elements.waveCanvas;
  const context = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  const centerY = height / 2;
  const data = new Uint8Array(state.analyser?.fftSize || 1024);

  function frame() {
    context.clearRect(0, 0, width, height);
    drawGrid(context, width, height);

    let level = 0;
    if (state.analyser) {
      state.analyser.getByteTimeDomainData(data);
      let sum = 0;
      for (const value of data) {
        const normalized = (value - 128) / 128;
        sum += normalized * normalized;
      }
      level = Math.sqrt(sum / data.length);
    }

    state.levelHistory.push(level);
    state.levelHistory.shift();
    elements.levelFill.style.width = `${Math.min(100, level * 420)}%`;

    context.lineWidth = 5;
    context.lineCap = "round";
    context.strokeStyle = "#2dd4bf";
    context.beginPath();
    state.levelHistory.forEach((sample, index) => {
      const x = (index / (state.levelHistory.length - 1)) * width;
      const y = centerY - sample * height * 1.35 + Math.sin(index / 10) * 7;
      if (index === 0) context.moveTo(x, y);
      else context.lineTo(x, y);
    });
    context.stroke();

    state.animationFrame = window.requestAnimationFrame(frame);
  }

  frame();
}

function drawIdleWaveform() {
  const canvas = elements.waveCanvas;
  const context = canvas.getContext("2d");
  const width = canvas.width;
  const height = canvas.height;
  context.clearRect(0, 0, width, height);
  drawGrid(context, width, height);
  context.lineWidth = 5;
  context.strokeStyle = "#25c2d8";
  context.beginPath();
  for (let x = 0; x <= width; x += 18) {
    const y = height / 2 + Math.sin(x / 84) * 18 + Math.sin(x / 33) * 7;
    if (x === 0) context.moveTo(x, y);
    else context.lineTo(x, y);
  }
  context.stroke();
}

function drawGrid(context, width, height) {
  context.fillStyle = "#111827";
  context.fillRect(0, 0, width, height);
  context.strokeStyle = "rgba(255, 255, 255, 0.08)";
  context.lineWidth = 2;
  for (let y = 46; y < height; y += 58) {
    context.beginPath();
    context.moveTo(0, y);
    context.lineTo(width, y);
    context.stroke();
  }
}

function updateTimer(forceZero = false) {
  elements.timer.textContent = formatDuration(forceZero ? 0 : currentElapsedMs());
}

function currentElapsedMs() {
  if (!state.startedAt) return 0;
  const pausedNow = state.pausedAt ? Date.now() - state.pausedAt : 0;
  return Math.max(0, Date.now() - state.startedAt - state.pausedMs - pausedNow);
}

async function sha256(buffer) {
  if (!crypto.subtle) return `bytes-${buffer.byteLength}`;
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function processTranscript() {
  state.transcript = elements.transcriptInput.value.trim();
  if (!state.transcript) {
    setStatus("ready", "Нет текста");
    switchTab("transcript");
    return;
  }

  setStatus("processing");
  const sentences = splitSentences(state.transcript);
  state.summary = buildSummary(sentences, state.transcript);
  state.decisions = extractTextMatches(sentences, [
    /\b(decision|decided|approved|selected|choose|we will|ship with)\b/i,
    /(решили|выбрали|утвердили|согласовали|оставляем|берем|договорились)/i,
  ]);
  state.risks = extractTextMatches(sentences, [
    /\b(risk|blocker|problem|issue|unclear|missing|broken|fail)\b/i,
    /(риск|проблем|непонят|слом|не работает|блокер|не хватает)/i,
  ]);
  state.actions = extractActions(sentences);
  persist();
  setStatus("ready", "AI-выжимка готова");
  switchTab("summary");
}

function splitSentences(text) {
  return text
    .replace(/\s+/g, " ")
    .split(/(?<=[.!?])\s+|\n+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
}

function buildSummary(sentences, text) {
  const mode = modeLabel();
  const lead = sentences.slice(0, Math.min(3, sentences.length)).join(" ");
  const metrics = `${wordCount(text)} слов · ${fragmentLabel(state.chunks.length)} · ${selectedModel().shortTitle}`;
  if (mode === "Диктовка") {
    return `${lead}${sentences.length > 3 ? " ..." : ""}\n\n${metrics}`;
  }
  return `${mode}: ${lead}${sentences.length > 3 ? " ..." : ""}\n\n${metrics}`;
}

function extractTextMatches(sentences, patterns) {
  return sentences
    .filter((sentence) => patterns.some((pattern) => pattern.test(sentence)))
    .slice(0, 6);
}

function extractActions(sentences) {
  const actionPatterns = [
    /\b(action|todo|follow up|need to|we need|please|ship|fix|prepare|send|review|decide|build)\b/i,
    /(надо|нужно|сделать|давай|подготов|отправ|проверь|исправ|допил|запусти|добавь)/i,
  ];
  const matches = extractTextMatches(sentences, actionPatterns);
  return matches.slice(0, 8).map((sentence, index) => ({
    id: crypto.randomUUID(),
    title: actionTitle(sentence),
    source: sentence,
    evidence: `T+${String(index + 1).padStart(2, "0")}:00 · ${sentence}`,
    owner: inferOwner(sentence),
    calendarState: "",
    priority: index === 0 ? "Важно" : "Обычно",
    done: false,
  }));
}

function inferOwner(sentence) {
  if (/сергей/i.test(sentence)) return "Сергей";
  if (/user|пользователь/i.test(sentence)) return "Пользователь";
  if (/we|мы|договорились/i.test(sentence)) return "Команда";
  return "Not stated";
}

function actionTitle(sentence) {
  const extracted = sentence.match(/(?:надо|нужно)\s+(.+)/i)?.[1]
    ?? sentence.match(/(?:допилить|запустить|добавить|сделать|проверить|исправить)\s+(.+)/i)?.[0]
    ?? sentence
        .replace(/^Договорились\s+/i, "")
        .replace(/^Please\s+/i, "")
        .replace(/^We need to\s+/i, "");
  const cleaned = extracted
    .replace(/^(надо|нужно|давай|please|we need to|need to)\s+/i, "")
    .trim();
  const titled = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
  return titled.length > 118 ? `${titled.slice(0, 115)}...` : titled;
}

function fillSampleText() {
  state.transcript = sampleTranscript;
  elements.transcriptInput.value = sampleTranscript;
  persist();
  processTranscript();
}

function runDemo() {
  state.sessionId = crypto.randomUUID();
  state.mode = "Meeting";
  state.selectedModel = "whisper_cpp_small";
  state.chunkWindowSec = 5;
  state.chunks = [
    demoChunk(0, 154_624, 5_000),
    demoChunk(1, 149_312, 5_000),
    demoChunk(2, 162_048, 5_000),
  ];
  state.markers = [
    { label: "Выбор модели", offsetMs: 4_800 },
    { label: "UX проблема", offsetMs: 9_900 },
  ];
  state.transcript = sampleTranscript;
  elements.transcriptInput.value = sampleTranscript;
  processTranscript();
}

function demoChunk(sequence, bytes, durationMs) {
  return {
    id: `${state.sessionId}-${sequence}`,
    sequence,
    state: "verified",
    bytes,
    durationMs,
    checksum: `sha256:${crypto.randomUUID().replaceAll("-", "")}${sequence}`,
    mimeType: "audio/webm",
    createdAt: new Date(Date.now() - (3 - sequence) * 5_000).toISOString(),
  };
}

function clearTranscript() {
  state.transcript = "";
  state.summary = "";
  state.actions = [];
  state.decisions = [];
  state.risks = [];
  persist();
  render();
  switchTab("transcript");
}

function toggleBrowserSpeech() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    alert("Браузерная речь здесь недоступна. Native Intel путь будет использовать локальный whisper.cpp.");
    return;
  }

  if (state.speechActive && state.speechRecognition) {
    state.speechRecognition.stop();
    return;
  }

  const recognition = new SpeechRecognition();
  recognition.continuous = true;
  recognition.interimResults = true;
  recognition.lang = navigator.language || "ru-RU";
  state.speechRecognition = recognition;
  state.speechActive = true;
  elements.browserSpeechBtn.textContent = "Остановить речь";
  setStatus("processing", "Браузерная речь");

  let committed = elements.transcriptInput.value.trim();
  recognition.onresult = (event) => {
    let interim = "";
    for (let index = event.resultIndex; index < event.results.length; index += 1) {
      const result = event.results[index];
      if (result.isFinal) committed = `${committed} ${result[0].transcript}`.trim();
      else interim += result[0].transcript;
    }
    state.transcript = `${committed}${interim ? ` ${interim}` : ""}`.trim();
    elements.transcriptInput.value = state.transcript;
    persist();
    render();
  };
  recognition.onend = () => {
    state.speechActive = false;
    state.speechRecognition = null;
    elements.browserSpeechBtn.textContent = "Браузерная речь";
    setStatus("ready");
  };
  recognition.onerror = () => {
    state.speechActive = false;
    state.speechRecognition = null;
    elements.browserSpeechBtn.textContent = "Браузерная речь";
    setStatus("ready");
  };
  recognition.start();
}

function addManualTask() {
  const nextNumber = state.actions.length + 1;
  state.actions.unshift({
    id: crypto.randomUUID(),
    title: `Ручная задача ${nextNumber}`,
    source: "Вручную",
    evidence: "Manual task · user-created",
    owner: "Not stated",
    calendarState: "",
    priority: "Обычно",
    done: false,
  });
  persist();
  render();
}

function scheduleTask(index) {
  const task = state.actions[index];
  if (!task) return;
  task.calendarState = task.calendarState ? nextSuggestedSlot(index + 1) : nextSuggestedSlot(index);
  persist();
  setStatus("ready", "Задача поставлена");
  render();
}

function nextSuggestedSlot(index) {
  const hour = Math.min(18, 15 + index);
  return `Сегодня ${String(hour).padStart(2, "0")}:00`;
}

function exportJSON() {
  const payload = exportPayload();
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  downloadBlob(blob, `superdictate-${state.sessionId.slice(0, 8)}.json`);
}

function exportMarkdown() {
  const blob = new Blob([exportPackageText()], { type: "text/markdown;charset=utf-8" });
  downloadBlob(blob, `superdictate-${state.sessionId.slice(0, 8)}.md`);
}

function exportPayload() {
  return {
    exported_at: new Date().toISOString(),
    session_id: state.sessionId,
    mode: state.mode,
    selected_model: state.selectedModel,
    chunks: state.chunks.map(serializableChunk),
    markers: state.markers,
    transcript: state.transcript,
    summary: state.summary,
    decisions: state.decisions,
    risks: state.risks,
    actions: state.actions,
  };
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

function exportReady() {
  return Boolean(state.transcript.trim() || state.summary || state.actions.length || state.chunks.length);
}

function exportPackageText() {
  const selected = selectedModel();
  const lines = [
    "# SuperDictate Export",
    "",
    `Session: ${state.sessionId}`,
    `Mode: ${modeLabel()}`,
    `Model: ${selected.shortTitle}`,
    `Status: ${state.status}`,
    `Audio: ${fragmentLabel(state.chunks.length)} · ${formatBytes(state.chunks.reduce((sum, chunk) => sum + chunk.bytes, 0))}`,
    "",
    "## Transcript",
    "",
    state.transcript.trim() || "_No transcript yet._",
    "",
    "## Summary",
    "",
    state.summary || "_No summary yet._",
    "",
    "## Decisions",
    "",
    ...listOrEmpty(state.decisions),
    "",
    "## Risks",
    "",
    ...listOrEmpty(state.risks),
    "",
    "## Tasks",
    "",
    ...(state.actions.length
      ? state.actions.map((task) => `${task.done ? "- [x]" : "- [ ]"} ${task.title} (${task.priority})`)
      : ["_No tasks yet._"]),
  ];
  return lines.join("\n");
}

function listOrEmpty(items) {
  return items.length ? items.map((item) => `- ${item}`) : ["_None._"];
}

async function copyText(text, successLabel) {
  if (!text.trim()) return;
  await navigator.clipboard.writeText(text);
  setStatus("ready", successLabel);
}

function tasksAsText() {
  return state.actions
    .map((task) => `${task.done ? "[x]" : "[ ]"} ${task.title} (${task.priority})`)
    .join("\n");
}

function simulateCrash() {
  if (state.recorder && state.recorder.state !== "inactive") state.recorder.requestData();
  setStatus("crashed", "Сбой смоделирован");
}

async function recoverSession() {
  const storedChunks = await loadStoredChunks();
  if (storedChunks.length > state.chunks.length) state.chunks = storedChunks;
  setStatus(state.chunks.length ? "recovered" : "ready", state.chunks.length ? "Восстановлено" : "Чисто");
}

function switchTab(tab) {
  state.activeTab = tab;
  $$(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.dataset.panel === tab));
  $$(".nav-item[data-tab]").forEach((button) => button.classList.toggle("active", button.dataset.tab === tab));
  persist();
  render();
}

function selectedModel() {
  return modelCatalog.find((model) => model.id === state.selectedModel) || modelCatalog[0];
}

function scheduledTaskCount() {
  return state.actions.filter((task) => Boolean(task.calendarState)).length;
}

function inferPeople() {
  const text = state.transcript.toLowerCase();
  const people = [];
  if (/сергей/.test(text)) people.push({ name: "Сергей", role: "product owner", count: countMatches(text, /сергей/g) });
  if (/клиент|client/.test(text)) people.push({ name: "Клиент", role: "external stakeholder", count: countMatches(text, /клиент|client/g) });
  if (/команд|team|мы /.test(text)) people.push({ name: "Команда", role: "internal team", count: countMatches(text, /команд|team|мы /g) });
  return people;
}

function countMatches(text, pattern) {
  return [...text.matchAll(pattern)].length;
}

function runAsk() {
  const question = elements.askInput.value.trim();
  state.askQuestion = question;
  if (!question) {
    state.askAnswer = "Напишите вопрос по текущей записи, сегодняшнему дню или всей памяти.";
    persist();
    render();
    return;
  }

  const scopeLabel = {
    recording: "эта запись",
    today: "сегодня",
    client: "клиент/проект",
    history: "вся память",
  }[state.askScope] || state.askScope;

  const answer = [];
  answer.push(`Scope: ${scopeLabel}`);
  if (!state.transcript.trim()) {
    answer.push("Я не нашел transcript. Запустите демо, вставьте текст или сделайте запись.");
  } else if (/реш|decision|decid/i.test(question)) {
    answer.push(state.decisions.length ? `Решения:\n${listOrEmpty(state.decisions).join("\n")}` : "Я не нашел явных решений в transcript.");
  } else if (/риск|risk|block/i.test(question)) {
    answer.push(state.risks.length ? `Риски:\n${listOrEmpty(state.risks).join("\n")}` : "Я не нашел явных рисков в transcript.");
  } else if (/зада|действ|следующ|action|todo|next|делать/i.test(question)) {
    answer.push(state.actions.length ? `Следующие действия:\n${state.actions.map((task) => `- ${task.title} · ${task.calendarState || "без времени"}`).join("\n")}` : "Я не нашел задач. Попробуйте сделать AI Review.");
  } else {
    answer.push(state.summary || buildSummary(splitSentences(state.transcript), state.transcript));
  }
  answer.push("");
  answer.push("Evidence:");
  answer.push(...listOrEmpty([
    state.actions[0]?.evidence,
    state.decisions[0],
    state.risks[0],
  ].filter(Boolean)));

  state.askAnswer = answer.join("\n");
  persist();
  render();
}

function modeLabel() {
  return {
    Meeting: "Встреча",
    Discovery: "Discovery",
    Thought: "Мысль",
    Dictation: "Диктовка",
    Interview: "Интервью",
    Lecture: "Лекция",
    Daily: "Daily memory",
  }[state.mode] || state.mode;
}

function formatDuration(ms) {
  const total = Math.floor(ms / 1000);
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function russianPlural(count, one, few, many) {
  const mod10 = count % 10;
  const mod100 = count % 100;
  if (mod10 === 1 && mod100 !== 11) return `${count} ${one}`;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return `${count} ${few}`;
  return `${count} ${many}`;
}

function fragmentLabel(count) {
  return russianPlural(count, "фрагмент", "фрагмента", "фрагментов");
}

function taskLabel(count) {
  return russianPlural(count, "задача", "задачи", "задач");
}

function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

elements.pipeline.addEventListener("click", (event) => {
  const step = event.target.closest(".pipeline-step[data-tab]");
  if (step) switchTab(step.dataset.tab);
});
elements.pipelineExport.addEventListener("click", () => switchTab("export"));
if (elements.navList) {
  elements.navList.addEventListener("click", (event) => {
    const button = event.target.closest(".nav-item[data-tab]");
    if (button) switchTab(button.dataset.tab);
  });
}
document.addEventListener("click", (event) => {
  const jump = event.target.closest("[data-tab-jump]");
  if (jump) switchTab(jump.dataset.tabJump);
});
elements.modeGrid.addEventListener("click", (event) => {
  const button = event.target.closest(".mode-row");
  if (!button) return;
  state.mode = button.dataset.mode;
  persist();
  render();
});
elements.modelSelect.addEventListener("change", () => {
  state.selectedModel = elements.modelSelect.value;
  persist();
  render();
});
elements.demoBtn.addEventListener("click", runDemo);
elements.exportBtn.addEventListener("click", exportJSON);
if (elements.startTodayBtn) {
  elements.startTodayBtn.addEventListener("click", () => {
    switchTab("recorder");
    startRecording().catch((error) => {
      console.error(error);
      alert(error.message || String(error));
      setStatus("idle");
    });
  });
}
if (elements.openTranscriptBtn) elements.openTranscriptBtn.addEventListener("click", () => switchTab("transcript"));
if (elements.openReviewBtn) elements.openReviewBtn.addEventListener("click", () => switchTab("summary"));
elements.recordBtn.addEventListener("click", () => {
  startRecording().catch((error) => {
    console.error(error);
    alert(error.message || String(error));
    setStatus("idle");
  });
});
elements.pauseBtn.addEventListener("click", pauseRecording);
elements.markerBtn.addEventListener("click", addMarker);
elements.stopBtn.addEventListener("click", stopRecording);
elements.browserSpeechBtn.addEventListener("click", toggleBrowserSpeech);
elements.sampleTextBtn.addEventListener("click", fillSampleText);
elements.processTextBtn.addEventListener("click", processTranscript);
elements.clearTextBtn.addEventListener("click", clearTranscript);
elements.copyTranscriptBtn.addEventListener("click", () => copyText(state.transcript, "Текст скопирован"));
elements.copySummaryBtn.addEventListener("click", () => copyText(state.summary, "Выжимка скопирована"));
elements.summaryToTasksBtn.addEventListener("click", () => switchTab("tasks"));
elements.addTaskBtn.addEventListener("click", addManualTask);
elements.copyTasksBtn.addEventListener("click", () => copyText(tasksAsText(), "Задачи скопированы"));
elements.crashBtn.addEventListener("click", simulateCrash);
elements.recoverBtn.addEventListener("click", recoverSession);
if (elements.copyPackageBtn) {
  elements.copyPackageBtn.addEventListener("click", () => copyText(exportPackageText(), "Пакет скопирован"));
}
if (elements.downloadMarkdownBtn) {
  elements.downloadMarkdownBtn.addEventListener("click", exportMarkdown);
}
if (elements.askScopeList) {
  elements.askScopeList.addEventListener("click", (event) => {
    const button = event.target.closest(".scope-chip[data-scope]");
    if (!button) return;
    state.askScope = button.dataset.scope;
    persist();
    render();
  });
}
if (elements.askInput) {
  elements.askInput.addEventListener("input", () => {
    state.askQuestion = elements.askInput.value;
    persist();
  });
}
if (elements.askRunBtn) elements.askRunBtn.addEventListener("click", runAsk);
if (elements.globalSearch) {
  elements.globalSearch.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    state.askQuestion = elements.globalSearch.value.trim();
    if (state.askQuestion) {
      switchTab("ask");
      elements.askInput.value = state.askQuestion;
      runAsk();
    }
  });
}
elements.chunkWindowSelect.addEventListener("change", () => {
  state.chunkWindowSec = Number(elements.chunkWindowSelect.value);
  persist();
  render();
});
elements.transcriptInput.addEventListener("input", () => {
  state.transcript = elements.transcriptInput.value;
  persist();
  render();
});

hydrate();
if (!["today", "recorder", "library", "transcript", "summary", "tasks", "ask", "people", "models", "settings", "export"].includes(state.activeTab)) state.activeTab = "today";
setStatus(state.status === "crashed" || state.status === "recoverable" ? state.status : "ready");
switchTab(state.activeTab);
drawIdleWaveform();
