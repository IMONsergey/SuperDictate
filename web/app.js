"use strict";

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const elements = {
  runtimeLine: $("#runtimeLine"),
  runtimeDot: $("#runtimeDot"),
  runtimeStatus: $("#runtimeStatus"),
  modelSelect: $("#modelSelect"),
  demoBtn: $("#demoBtn"),
  exportBtn: $("#exportBtn"),
  pipeline: $("#pipeline"),
  pipelineExport: $("#pipelineExport"),
  stepRecord: $("#stepRecord"),
  stepTranscript: $("#stepTranscript"),
  stepSummary: $("#stepSummary"),
  stepTasks: $("#stepTasks"),
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
};

const STORAGE_KEY = "superdictate.web.workbench.v2";
const DB_NAME = "superdictate-web-workbench";
const DB_VERSION = 1;
const CHUNK_STORE = "chunks";

const modelCatalog = [
  {
    id: "whisper_cpp_base",
    title: "Whisper.cpp Base",
    shortTitle: "Whisper.cpp Base",
    subtitle: "Лучший старт для Intel: бесплатно, локально, RU/EN, CPU.",
    status: "выбрана",
    tags: ["Intel", "RU/EN", "~150 MB"],
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
    id: "whisper_cpp_small",
    title: "Whisper.cpp Small",
    shortTitle: "Whisper Small",
    subtitle: "Следующий кандидат, когда стабилизируем latency на Intel.",
    status: "следующая",
    tags: ["качество", "медленнее"],
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

const sampleTranscript = `Решили тестировать Intel preview на Whisper.cpp Base, потому что модель бесплатная, локальная и достаточно быстрая для первого запуска на CPU. Нужно сделать интерфейс понятнее: показать шаги записи, транскрипта, выжимки, задач и экспорта. Сергей попросил, чтобы пользователь мог выбрать модель, а по умолчанию для Intel стоял Whisper.cpp Base. Риск: web preview не должен притворяться полноценным native ASR, поэтому надо явно показывать, где браузерная демо-обработка, а где будущий native whisper.cpp. Договорились сначала довести рабочий web workbench, потом допилить native Intel backend и открыть PR.`;

const state = {
  sessionId: crypto.randomUUID(),
  mode: "Dictation",
  status: "idle",
  activeTab: "recorder",
  selectedModel: "whisper_cpp_base",
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
}

function renderModelControls() {
  const selected = selectedModel();
  elements.runtimeLine.textContent = `Локальная диктовка · ${selected.shortTitle}`;
  elements.selectedModelLabel.textContent = selected.shortTitle;

  elements.modelSelect.innerHTML = modelCatalog
    .filter((model) => model.id !== "local_summarizer")
    .map((model) => `<option value="${model.id}">${escapeHtml(model.shortTitle)}</option>`)
    .join("");
  elements.modelSelect.value = state.selectedModel;

  elements.modelList.innerHTML = "";
  for (const model of modelCatalog) {
    const card = document.createElement("article");
    card.className = `model-card${model.id === state.selectedModel ? " active" : ""}`;
    card.innerHTML = `
      <h3>${escapeHtml(model.title)}</h3>
      <p>${escapeHtml(model.subtitle)}</p>
      <div class="model-meta">
        <span class="pill">${escapeHtml(model.status)}</span>
        ${model.tags.map((tag) => `<span class="pill">${escapeHtml(tag)}</span>`).join("")}
      </div>
    `;
    if (model.id !== "local_summarizer") {
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
  elements.stepSummary.textContent = state.summary ? "готова" : "не создана";
  elements.stepTasks.textContent = taskLabel(state.actions.length);
}

function stepComplete(tab) {
  if (tab === "recorder") return state.chunks.length > 0;
  if (tab === "transcript") return state.transcript.trim().length > 0;
  if (tab === "summary") return Boolean(state.summary);
  if (tab === "tasks") return state.actions.length > 0;
  return false;
}

function renderSession() {
  const modeLabels = {
    Meeting: "Встреча",
    Thought: "Мысль",
    Dictation: "Диктовка",
    Interview: "Интервью",
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
  elements.summaryStatus.textContent = state.summary ? "Выжимка создана локально в preview." : "Добавьте текст и запустите выжимку.";
  elements.taskStatus.textContent = state.actions.length ? taskLabel(state.actions.length) : "Задачи появятся после выжимки.";
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
        <p>${escapeHtml(task.source)}</p>
      </div>
      <span class="task-priority">${escapeHtml(task.priority)}</span>
    `;
    item.querySelector("input").addEventListener("change", (event) => {
      state.actions[index].done = event.target.checked;
      persist();
      render();
    });
    elements.taskList.appendChild(item);
  });
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
    priority: index === 0 ? "Важно" : "Обычно",
    done: false,
  }));
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
  return titled.length > 72 ? `${titled.slice(0, 69)}...` : titled;
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
  state.selectedModel = "whisper_cpp_base";
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
  const title = prompt("Новая задача");
  if (!title?.trim()) return;
  state.actions.unshift({
    id: crypto.randomUUID(),
    title: title.trim(),
    source: "Вручную",
    priority: "Обычно",
    done: false,
  });
  persist();
  render();
}

function exportJSON() {
  const payload = {
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
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `superdictate-${state.sessionId.slice(0, 8)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
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
  persist();
  render();
}

function selectedModel() {
  return modelCatalog.find((model) => model.id === state.selectedModel) || modelCatalog[0];
}

function modeLabel() {
  return {
    Meeting: "Встреча",
    Thought: "Мысль",
    Dictation: "Диктовка",
    Interview: "Интервью",
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
elements.pipelineExport.addEventListener("click", exportJSON);
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
if (!["recorder", "transcript", "summary", "tasks"].includes(state.activeTab)) state.activeTab = "recorder";
setStatus(state.status === "crashed" || state.status === "recoverable" ? state.status : "ready");
switchTab(state.activeTab);
drawIdleWaveform();
