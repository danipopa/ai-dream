# ai-dream OpenVoice service

Private inference API for OpenVoice V2 voice cloning with MeloTTS base speech. The service is intended to be reachable only by the Rails backend.

## API

- `GET /health`
- `POST /v1/voices` — multipart fields `name` and `sample`; returns a private voice ID
- `POST /v1/speech/:voice_id` — JSON fields `text`, `language`, and optional `speed`; returns WAV audio

When `VOICE_SERVICE_TOKEN` is set, model endpoints require the same value in `X-Internal-Token`. Health checks do not require it.

## Runtime notes

- The image preloads the English MeloTTS model. Other language models are fetched the first time they are used, so preload them during image construction for an air-gapped deployment.
- Run one Uvicorn worker per GPU. The service serializes inference to limit GPU-memory pressure.
- `/data` contains source recordings, derived speaker embeddings, and temporary output. Back it with encrypted persistent storage and include it in deletion workflows.
- Pin the OpenVoice and MeloTTS build arguments to audited commit SHAs before promoting an image to production.
