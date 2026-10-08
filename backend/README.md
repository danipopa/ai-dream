# ai-dream backend

Rails API gateway for the ai-dream microservices backend.

## Setup

Development and production use PostgreSQL. The Compose stack provides PostgreSQL automatically; for a direct Rails server, set `DATABASE_HOST`, `DATABASE_NAME`, `DATABASE_USER`, and `DATABASE_PASSWORD` for a reachable PostgreSQL instance. Tests continue to use SQLite locally. Existing SQLite data is not migrated automatically.

```sh
bundle install
bin/rails db:migrate
bin/rails server
```

## Service Boundaries

- `MemoryServices`: memory records and photo uploads
- `ConversationServices`: age-aware memory-person replies
- `MediaServices`: video plan and render orchestration
- `VoiceServices`: consent-aware voice cloning and speech generation

The app is currently one deployable service with boundaries kept in code. See `docs/microservices.md` for the extraction plan.

## API

- `GET /api/v1/memories`
- `POST /api/v1/memories`
- `GET /api/v1/memories/:id`
- `PATCH /api/v1/memories/:id`
- `DELETE /api/v1/memories/:id`
- `GET /api/v1/memories/:memory_id/conversation`
- `POST /api/v1/memories/:memory_id/conversation`
- `GET /api/v1/memories/:memory_id/videos`
- `POST /api/v1/memories/:memory_id/videos`
- `GET|POST /api/v1/memories/:memory_id/voice`
- `GET|POST /api/v1/memories/:memory_id/speech`

Set `VOICE_SERVICE_URL` and `VOICE_SERVICE_TOKEN` to connect Rails to the private OpenVoice service. Without a service URL, the API returns a `browser_preview` profile and the frontend uses the Web Speech API. Explicit voice-owner permission is required in both modes.

Conversation replies and video scripts use the provider selected by `LLM_PROVIDER` (`ollama` by default or `fireworks`). Ollama uses `OLLAMA_URL` (default `http://ollama:11434`) and `OLLAMA_MODEL` (default `qwen2.5:3b`). Fireworks uses `FIREWORKS_API_KEY` and `FIREWORKS_MODEL` (default `accounts/fireworks/models/glm-5p3-flash`) through its HTTPS chat-completions API. Provider failures return `503`; the app does not silently substitute template output. Fireworks receives the memory and conversation text and may charge for inference.

## Tests

```sh
bin/rails test
```
