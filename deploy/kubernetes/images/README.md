# Offline Kubernetes image bundle

The archives in this directory are gzip-compressed Docker image saves. The
ai-dream deployment pulls its project images from the in-cluster registry; see
[`../../../docker-registry/README.md`](../../../docker-registry/README.md)
for pushing them there. PostgreSQL is pulled from Docker Hub as `postgres:16`.
The archives are a fallback if you choose not to use the registry. For that
fallback, import all images on every Kubernetes node that may schedule
ai-dream workloads. Their local tags are:

- `ai-dream-backend:release`
- `ai-dream-frontend:release`
- `ai-dream-ollama:release` (includes `qwen2.5:3b`)
- `ai-dream-voice:release`
- `postgres:16`

Verify transferred archives, then import them on each node:

```sh
sha256sum -c SHA256SUMS
for archive in *.tar.gz; do
  sudo ctr -n k8s.io images import "$archive"
done
sudo ctr -n k8s.io images list
```

To use this fallback, change the five app image references in
`../base/services.yaml`, `../base/gateway.yaml`, `../base/llm.yaml`, and
`../base/database.yaml` back to the local tags listed above. Importing images
does not deploy the application.
