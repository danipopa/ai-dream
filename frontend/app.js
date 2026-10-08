const localStaticServer = ["localhost", "127.0.0.1"].includes(window.location.hostname) && window.location.port === "8080";
const API_BASE = window.AI_DREAM_API_BASE || (localStaticServer ? `http://${window.location.hostname}:3000` : "");

let activeMemory = null;
let memories = [];

const memoryForm = document.querySelector("#memory-form");
const memoryList = document.querySelector("#memory-list");
const refreshButton = document.querySelector("#refresh-memories");
const emptyState = document.querySelector("#empty-state");
const workspace = document.querySelector("#memory-workspace");
const activePerson = document.querySelector("#active-person");
const activeTitle = document.querySelector("#active-title");
const activeStory = document.querySelector("#active-story");
const photoStrip = document.querySelector("#photo-strip");
const conversationLog = document.querySelector("#conversation-log");
const conversationForm = document.querySelector("#conversation-form");
const conversationStatus = document.querySelector("#conversation-status");
const videoForm = document.querySelector("#video-form");
const videoStatus = document.querySelector("#video-status");
const videoJobs = document.querySelector("#video-jobs");
const voiceForm = document.querySelector("#voice-form");
const voiceStatus = document.querySelector("#voice-status");
const speechForm = document.querySelector("#speech-form");
const speechList = document.querySelector("#speech-list");
const speechLanguage = document.querySelector("#speech-language");

memoryForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const formData = new FormData(memoryForm);
  await fetch(`${API_BASE}/api/v1/memories`, {
    method: "POST",
    body: formData
  });

  memoryForm.reset();
  await loadMemories();
});

refreshButton.addEventListener("click", loadMemories);

conversationForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!activeMemory) return;

  const formData = new FormData(conversationForm);
  const submitButton = conversationForm.querySelector('[type="submit"]');
  submitButton.disabled = true;
  setLlmStatus(conversationStatus, "Generating an AI response…", "pending");

  try {
    await postLlmRequest(`/api/v1/memories/${activeMemory.id}/conversation`, {
      message: formData.get("message"),
      age_years: formData.get("age_years")
    });
    conversationForm.reset();
    await loadConversation(activeMemory.id);
    setLlmStatus(conversationStatus, "");
  } catch (error) {
    setLlmStatus(conversationStatus, error.message, "failed");
  } finally {
    submitButton.disabled = false;
  }
});

videoForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!activeMemory) return;

  const formData = new FormData(videoForm);
  const submitButton = videoForm.querySelector('[type="submit"]');
  submitButton.disabled = true;
  setLlmStatus(videoStatus, "Generating a video script…", "pending");

  try {
    await postLlmRequest(`/api/v1/memories/${activeMemory.id}/videos`, {
      prompt: formData.get("prompt")
    });
    videoForm.reset();
    await loadVideoJobs(activeMemory.id);
    setLlmStatus(videoStatus, "");
  } catch (error) {
    setLlmStatus(videoStatus, error.message, "failed");
  } finally {
    submitButton.disabled = false;
  }
});

voiceForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!activeMemory) return;

  setVoiceStatus("Creating voice profile…", "pending");
  const response = await fetch(`${API_BASE}/api/v1/memories/${activeMemory.id}/voice`, {
    method: "POST",
    body: new FormData(voiceForm)
  });
  const result = await response.json();

  if (!response.ok) {
    setVoiceStatus(result.errors?.join(" ") || result.error_message || "Voice profile creation failed.", "failed");
    return;
  }

  voiceForm.reset();
  renderVoiceProfile(result);
});

speechForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const formData = new FormData(speechForm);
  await generateSpeech(formData.get("text"), null, formData.get("language"));
  speechForm.reset();
});

async function loadMemories() {
  const response = await fetch(`${API_BASE}/api/v1/memories`);
  memories = await response.json();
  renderMemories();

  if (activeMemory) {
    const updated = memories.find((memory) => memory.id === activeMemory.id);
    if (updated) selectMemory(updated);
  }
}

function renderMemories() {
  memoryList.innerHTML = "";

  if (memories.length === 0) {
    memoryList.innerHTML = '<p class="muted">No memories yet.</p>';
    return;
  }

  memories.forEach((memory) => {
    const button = document.createElement("button");
    button.className = `memory-card ${activeMemory?.id === memory.id ? "active" : ""}`;
    button.type = "button";
    button.innerHTML = `
      <h3>${escapeHtml(memory.title)}</h3>
      <p>${escapeHtml(memory.person_name)}${memory.memory_date ? ` · ${memory.memory_date}` : ""}</p>
    `;
    button.addEventListener("click", () => selectMemory(memory));
    memoryList.appendChild(button);
  });
}

async function selectMemory(memory) {
  activeMemory = memory;
  emptyState.hidden = true;
  workspace.hidden = false;

  activePerson.textContent = `${memory.person_name}${memory.person_age_at_memory ? `, age ${memory.person_age_at_memory}` : ""}`;
  activeTitle.textContent = memory.title;
  activeStory.textContent = memory.story;
  renderPhotos(memory.photos || []);
  renderMemories();

  await Promise.all([
    loadConversation(memory.id),
    loadVideoJobs(memory.id),
    loadVoiceProfile(memory.id),
    loadSpeechGenerations(memory.id)
  ]);
}

function renderPhotos(photos) {
  photoStrip.innerHTML = "";

  photos.forEach((photoPath) => {
    const image = document.createElement("img");
    image.src = `${API_BASE}${photoPath}`;
    image.alt = "";
    photoStrip.appendChild(image);
  });
}

async function loadConversation(memoryId) {
  const response = await fetch(`${API_BASE}/api/v1/memories/${memoryId}/conversation`);
  const messages = await response.json();

  conversationLog.innerHTML = messages.map((message) => `
    <div class="message ${message.speaker}">
      <strong>${message.speaker === "user" ? "You" : "Memory person"}${message.age_years ? ` · age ${message.age_years}` : ""}</strong>
      <p>${escapeHtml(message.content)}</p>
      ${message.speaker === "memory_person" ? `<button type="button" class="speak-message" data-message-id="${message.id}" data-text="${escapeAttribute(message.content)}">Speak this reply</button>` : ""}
    </div>
  `).join("");

  conversationLog.querySelectorAll(".speak-message").forEach((button) => {
    button.addEventListener("click", () => generateSpeech(button.dataset.text, button.dataset.messageId));
  });
}

async function loadVideoJobs(memoryId) {
  const response = await fetch(`${API_BASE}/api/v1/memories/${memoryId}/videos`);
  const jobs = await response.json();

  videoJobs.innerHTML = jobs.map((job) => `
    <div class="video-job">
      <strong>${escapeHtml(job.status)}</strong>
      <p>${escapeHtml(job.generated_script || job.prompt)}</p>
    </div>
  `).join("");
}

async function postLlmRequest(path, body) {
  let response;
  try {
    response = await fetch(`${API_BASE}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
  } catch (error) {
    if (error instanceof TypeError) {
      throw new Error("Could not reach the API or local language model. Check that the services are running.");
    }
    throw error;
  }

  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.error_message || result.errors?.join(" ") || `Request failed (${response.status}).`);
  }
  return result;
}

function setLlmStatus(element, message, status = "") {
  element.textContent = message;
  element.dataset.status = status;
  element.hidden = !message;
}

async function loadVoiceProfile(memoryId) {
  const response = await fetch(`${API_BASE}/api/v1/memories/${memoryId}/voice`);
  if (response.status === 204) {
    setVoiceStatus("No voice profile yet.");
    return;
  }

  renderVoiceProfile(await response.json());
}

function renderVoiceProfile(profile) {
  if (profile.status === "failed") {
    setVoiceStatus(profile.error_message || "Voice profile creation failed.", "failed");
    return;
  }

  const providerLabel = profile.provider === "openvoice"
    ? "Self-hosted OpenVoice clone"
    : "Browser preview — not a cloned voice";
  setVoiceStatus(`${profile.status} · ${providerLabel}`, profile.status);
}

function setVoiceStatus(message, status = "empty") {
  voiceStatus.textContent = message;
  voiceStatus.dataset.status = status;
}

async function generateSpeech(text, conversationMessageId = null, language = speechLanguage.value) {
  if (!activeMemory || !text) return;

  const response = await fetch(`${API_BASE}/api/v1/memories/${activeMemory.id}/speech`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text, conversation_message_id: conversationMessageId, language })
  });
  const result = await response.json();

  if (!response.ok) {
    setVoiceStatus(result.errors?.join(" ") || result.error_message || "Speech generation failed.", "failed");
    return;
  }

  if (result.audio_url) {
    const audio = new Audio(`${API_BASE}${result.audio_url}`);
    await audio.play();
  } else if ("speechSynthesis" in window) {
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(new SpeechSynthesisUtterance(result.text));
  }

  await loadSpeechGenerations(activeMemory.id);
}

async function loadSpeechGenerations(memoryId) {
  const response = await fetch(`${API_BASE}/api/v1/memories/${memoryId}/speech`);
  const generations = await response.json();

  speechList.innerHTML = generations.map((generation) => `
    <div class="speech-item">
      <p><strong>${escapeHtml(generation.language)}</strong> · ${escapeHtml(generation.text)}</p>
      ${generation.audio_url
        ? `<audio controls preload="none" src="${API_BASE}${escapeAttribute(generation.audio_url)}"></audio>`
        : '<span class="preview-label">Browser preview</span>'}
    </div>
  `).join("");
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replaceAll("`", "&#096;");
}

loadMemories().catch(() => {
  memoryList.innerHTML = '<p class="muted">Start the Rails API on port 3000 to load memories.</p>';
});
