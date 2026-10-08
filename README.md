# ai-dream

ai-dream is a memory-to-video application. People upload photos and written memories, create cinematic video plans, and talk with a remembered person through an age-aware persona.

## Current Shape

- `backend/` is a Rails API gateway with service-oriented boundaries for memories, conversation, media, and voice.
- `frontend/` is a static no-build web app served by Nginx in the on-prem stack.
- `voice-service/` is a private Python inference API built on OpenVoice V2 and MeloTTS.
- Conversations and video-script planning use a private Ollama service with the free/open-weight Qwen2.5 3B model by default.

The backend starts as one deployable Rails service while keeping domain logic in service namespaces that can later split into separate microservices:

- `MemoryServices` owns memory records and uploaded photo persistence.
- `ConversationServices` owns age-aware memory-person replies.
- `MediaServices` owns video scripting and rendering job orchestration.
- `VoiceServices` owns consent-aware voice samples, cloning-provider integration, and speech generation.

## Self-hosted Voice Cloning

The voice workflow requires explicit permission with every uploaded sample. OpenVoice V2 and its published checkpoints are MIT licensed and run inside your infrastructure. It supports English, Spanish, French, Chinese, Japanese, and Korean. No voice sample is sent to a hosted model provider.

Without `VOICE_SERVICE_URL`, Rails uses a browser speech preview for lightweight local development. The UI clearly marks that preview as not cloned.

By default, language-model requests run inside your infrastructure through Ollama, which downloads `qwen2.5:3b` on first startup and keeps model files in persistent storage. You can instead select Fireworks with `LLM_PROVIDER=fireworks` and configure an API key/model; this sends memory and conversation text to Fireworks and may incur charges. Conversation replies are disclosed as AI-generated imaginative reflections; video planning produces a script, not a rendered video.

## On-prem Deployment

Requirements:

- Docker Engine with the Compose plugin
- 16 GB RAM minimum; more is recommended for concurrent CPU voice and LLM inference
- An NVIDIA GPU with the NVIDIA Container Toolkit for practical inference latency, or CPU mode for evaluation
- Internet access while building the images and on first startup so model files can be fetched

Configure and start the CPU stack:

```sh
cp .env.example .env
# Replace all placeholder secrets in .env.
docker compose up --build -d
```

To use Fireworks instead of Ollama, set `LLM_PROVIDER=fireworks`, `FIREWORKS_API_KEY`, and `FIREWORKS_MODEL` in `.env`. Fireworks API requests require outbound HTTPS access and send the memory story and conversation to Fireworks. The Compose stack still starts its Ollama service; Kubernetes has a Fireworks overlay that scales Ollama down.

For an NVIDIA GPU:

```sh
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up --build -d
```

Open `http://your-server:8088`. Only Nginx is published; Rails, PostgreSQL, and the model services remain on the internal Compose network. Named volumes retain the database, uploads, generated audio, voice embeddings, and Ollama model files.

For an air-gapped cloud, build the images in a connected environment, pin `OPENVOICE_REF` and `MELOTTS_REF` to reviewed commit SHAs, push the images to your internal registry, and change the Compose file from `build:` to those immutable image tags.

Voice samples and embeddings are sensitive biometric data. Before production use, add user authentication and authorization, encryption at rest, backup controls, deletion/retention workflows, audit logs, rate limits, and TLS at the ingress or load balancer.

## Local Setup

```sh
cd backend
bundle install
bin/rails db:migrate
bin/rails server
```

For a full local stack, use Docker Compose as above. To run Rails directly, provide PostgreSQL and Ollama, pull the configured model (default `qwen2.5:3b`), and set the database and `OLLAMA_URL`/`OLLAMA_MODEL` environment variables. Then serve `frontend/` on port 8080. The local UI uses Rails on port 3000 and falls back to browser speech unless `VOICE_SERVICE_URL` points to a running voice inference service.

## Next Microservice Split

1. Keep Rails as the API gateway and identity boundary.
2. Extract `ConversationServices` into a dedicated conversation service with its own datastore and model provider integration.
3. Extract `MediaServices` into a media service backed by async jobs, object storage, and a video generation provider.
4. Move uploads from local disk to object storage so every service can consume the same assets.

## Kubernetes API deployment

See [the Kubernetes deployment guide](deploy/kubernetes/README.md) for CPU/GPU manifests, persistent NFS storage, the authenticated NodePort web app/API gateway, and voice upload/speech generation examples.
