# Backend Microservices Plan

The Rails app is the first deployable backend, but it is organized around bounded service areas so the system can split cleanly.

## API Gateway

Rails owns public HTTP routes, request validation, authentication later, and response shapes.

Current routes:

- `GET /api/v1/memories`
- `POST /api/v1/memories`
- `GET /api/v1/memories/:id`
- `PATCH /api/v1/memories/:id`
- `DELETE /api/v1/memories/:id`
- `GET /api/v1/memories/:memory_id/conversation`
- `POST /api/v1/memories/:memory_id/conversation`
- `GET /api/v1/memories/:memory_id/videos`
- `POST /api/v1/memories/:memory_id/videos`

## Memory Service

Owns people, memories, photos, and factual context. The current implementation is `MemoryServices::PhotoStorage` plus the `Memory` model.

Future extraction:

- Database: memories, people, media assets
- Storage: S3-compatible object storage
- Events: `memory.created`, `photo.uploaded`

## Conversation Service

Owns age-aware conversation with the remembered person. The current implementation records user and memory-person messages, then returns a placeholder response.

Future extraction:

- Database: conversation sessions and messages
- Model integration: persona prompt, safety policy, voice settings
- Events: `conversation.message.created`

## Media Service

Owns video plans and rendering jobs. The current implementation creates a script and marks jobs as `scripting`.

Future extraction:

- Database: video jobs, render attempts
- Workers: script generation, image aging, voice, video render
- Events: `video_job.created`, `video_job.completed`, `video_job.failed`
