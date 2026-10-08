# Kubernetes deployment

The API path is NodePort `30080` → Nginx gateway → Rails → private PostgreSQL, OpenVoice, and Ollama services. The gateway has no password protection and Nginx uses HTTP. Use it only on a trusted LAN or access it through an SSH tunnel. The data services are not exposed externally.

The cluster has no NVIDIA GPU. Use `base`, which sets `VOICE_DEVICE=cpu` and runs Ollama on CPU. The voice container requests 2 CPU cores and 4 GiB RAM, with limits of 4 cores and 8 GiB. Ollama requests 4 CPU cores and 6 GiB RAM, with limits of 8 cores and 10 GiB. Validate scheduling, memory pressure, and inference latency before production traffic.

NFS is already exported from `192.168.100.1:/home/storage` to the cluster subnet. This deployment uses three static 20 GiB NFS PVs under `/home/storage/ai-dreams/` for PostgreSQL, uploads, and voice data. PVC sizes are Kubernetes capacity declarations; NFS does not enforce per-volume quotas. The existing export uses `no_root_squash`, so only use it with trusted cluster nodes.

## Configure

Prerequisites: Docker, access to a container registry that the Kubernetes nodes can pull from, and a CNI that enforces NetworkPolicy. The node IPs are `192.168.100.10`, `192.168.100.15`, and `192.168.100.16`. GPU mode additionally needs NVIDIA drivers and the NVIDIA device plugin.

1. Build the backend, voice, frontend, and Ollama images. The frontend image also serves the UI through the gateway. The voice build downloads large model files; use reviewed OpenVoice/MeloTTS commit SHAs for reproducibility. The Ollama image build embeds `qwen2.5:3b`, so the cluster does not need to download the model on first startup.

   ```sh
   docker build -t ai-dream-backend:release backend
   docker build --build-arg OPENVOICE_REF=YOUR_COMMIT --build-arg MELOTTS_REF=YOUR_COMMIT -t ai-dream-voice:release voice-service
   docker build -t ai-dream-frontend:release-ui-fix frontend
   docker build --build-arg OLLAMA_MODEL=qwen2.5:3b -t ai-dream-ollama:release -f deploy/kubernetes/ollama/Dockerfile deploy/kubernetes/ollama
   ```

2. Push the backend, frontend, voice, and Ollama images to the local registry as described in [`../../docker-registry/README.md`](../../docker-registry/README.md). The manifests use `192.168.100.16:30501` for those images; configure containerd on every worker to allow this HTTP registry before deploying. PostgreSQL uses the official `postgres:16` image from Docker Hub, so the worker nodes need Docker Hub access unless that image is already cached locally.

3. The VM already exports `/home/storage`; create only the app-specific directories (already created for this deployment). The PostgreSQL claim must use the PostgreSQL PV: the manifests pin each PVC to its matching PV to prevent Kubernetes from assigning these otherwise-identical claims to the wrong NFS directory.

   ```sh
   ssh -p 22122 root@10.0.0.250 \
     'install -d -m 0700 /home/storage/ai-dreams/app /home/storage/ai-dreams/voice && install -d -o 999 -g 999 -m 0700 /home/storage/ai-dreams/postgres /home/storage/ai-dreams/postgres/pgdata'
   ```

   If these claims were already created from an earlier version of the manifests, applying the PV pins will **not** reassign bound claims. Check the PVC-to-PV bindings before restarting workloads. Back up and plan a data-preserving PV/PVC migration before deleting or recreating any claims; PVs use `Retain`, and the existing claims may have written data to the wrong NFS directories.

   To select another Ollama model, rebuild the Ollama image with the new `OLLAMA_MODEL` build argument and set the same model in the `ollama-config` ConfigMap in `base/llm.yaml`.

4. Connect `kubectl` to the cluster. In one terminal, keep this SSH tunnel open:

   ```sh
   ssh -p 22122 -N -L 16443:192.168.100.10:6443 root@10.0.0.250
   ```

   In a second terminal, from the repository root, define a helper and verify access:

   ```sh
   kc() {
     kubectl --kubeconfig="$HOME/.kube/config-garaje" \
       --server=https://127.0.0.1:16443 \
       --tls-server-name=192.168.100.10 "$@"
   }
   kc get nodes
   ```

5. Create the namespace and application secrets. Keep generated secrets outside the repository:

   ```sh
   kc apply -f deploy/kubernetes/base/namespace.yaml
   umask 077
   secret_dir=$(mktemp -d)
   openssl rand -hex 64 > "$secret_dir/SECRET_KEY_BASE"
   openssl rand -hex 64 > "$secret_dir/VOICE_SERVICE_TOKEN"
   openssl rand -hex 32 > "$secret_dir/DATABASE_PASSWORD"
   # Remove trailing newlines so HTTP header values are valid.
   python3 -c 'from pathlib import Path; import sys; [p.write_bytes(p.read_bytes().strip()) for p in Path(sys.argv[1]).iterdir()]' "$secret_dir"
   kc -n ai-dream create secret generic ai-dream-secrets --from-file="$secret_dir/SECRET_KEY_BASE" --from-file="$secret_dir/VOICE_SERVICE_TOKEN" --from-file="$secret_dir/DATABASE_PASSWORD"
   rm -r "$secret_dir"
   ```

## Use Fireworks for language-model requests

The base deployment uses local Ollama. To use Fireworks-hosted inference instead:

1. Create a Fireworks API key and save it to a protected file outside the repository.
2. Create the separate Kubernetes Secret:

   ```sh
   kc -n ai-dream create secret generic fireworks-api-key \
     --from-file=FIREWORKS_API_KEY=/secure/path/to/FIREWORKS_API_KEY
   ```

3. Confirm `FIREWORKS_MODEL` in `base/llm.yaml` is a model ID available to your Fireworks account. The default is `accounts/fireworks/models/glm-5p3-flash`.
4. Apply the Fireworks overlay and restart the backend so it reads the provider configuration:

   ```sh
   kc apply -k deploy/kubernetes/fireworks
   kc -n ai-dream rollout restart deployment/backend
   kc -n ai-dream rollout status deployment/backend --timeout=5m
   ```

The overlay selects Fireworks and scales the unused local Ollama deployment to zero. The Kubernetes nodes need outbound HTTPS access to `api.fireworks.ai`. Conversation prompts contain the saved story and chat messages, so this option sends that text outside the cluster and may incur Fireworks charges. Keep the API key in the Kubernetes Secret, never in a manifest.

To switch back to local Ollama:

```sh
kc apply -k deploy/kubernetes/base
kc -n ai-dream rollout restart deployment/backend
```

There is no gateway login: anyone who can reach NodePort `30080` can read and modify project data. Restrict access to a trusted LAN or use the SSH tunnel; add authentication and TLS before exposing it to other networks.

## Deploy and verify

Run from the repository root:

```sh
kc apply --dry-run=server -k deploy/kubernetes/base
kc apply -k deploy/kubernetes/base
kc -n ai-dream rollout status deployment/postgres --timeout=10m
kc -n ai-dream rollout status deployment/ollama --timeout=30m
kc -n ai-dream rollout status deployment/voice --timeout=15m
kc -n ai-dream rollout status deployment/backend --timeout=15m
kc -n ai-dream rollout status deployment/api-gateway --timeout=5m
kc -n ai-dream get svc,pods,pvc
```

The Ollama model is bundled into the image, so model downloads happen during the image build rather than on the cluster. Once the gateway is ready, reach it at `http://192.168.100.10:30080` if that node address is routable from your client. Otherwise, open a second SSH tunnel to the NodePort:

```sh
ssh -p 22122 -N -L 13080:192.168.100.10:30080 root@10.0.0.250
```

Then use `http://127.0.0.1:13080`. The voice deployment has a 15-minute startup probe allowance. Readiness probes keep Ollama out of service until its model is available. Liveness probes are omitted for inference services to avoid restarting them during long inference. Rails runs database migrations at startup.

## Call the API

`curl -u project` prompts for the gateway password. Through the SSH tunnel, set `API_URL` like this:

```sh
API_URL=http://127.0.0.1:13080
curl --fail-with-body -u project "$API_URL/api/v1/memories" \
  -H 'Content-Type: application/json' \
  -d '{"person_name":"Speaker","title":"Voice demo","story":"A sample memory."}'

# Use the returned memory id.
MEMORY_ID=1
curl --fail-with-body -u project "$API_URL/api/v1/memories/$MEMORY_ID/voice" \
  -F 'consent_confirmed=true' -F 'sample=@sample.wav;type=audio/wav'

curl --fail-with-body -u project "$API_URL/api/v1/memories/$MEMORY_ID/speech" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello from my cloned voice.","language":"EN"}'
```

Download the returned `audio_url` using the same authentication (prefix relative paths with `API_URL`). Verify that the response reports a ready/completed result from OpenVoice rather than browser preview. Calls are synchronous; configure the calling client's timeout for model latency. The Rails provider times out after 180 seconds; long or queued requests may fail and require an asynchronous job design at larger scale.

## Operations

The backend, PostgreSQL, voice inference service, and Ollama each run one replica. PostgreSQL, uploads, and voice samples/embeddings use separate persistent volumes. The Ollama model is contained in its image. Data services use `Recreate` updates; updates can cause downtime. PostgreSQL is a single instance, not highly available. Back up PostgreSQL and voice data regularly. PVs use `Retain`; deleting the namespace does not delete the NFS files. Existing SQLite data is not migrated automatically.

The network policies only permit gateway → Rails, Rails → voice, and Rails → Ollama within this namespace. Outbound networking remains available for runtime downloads of additional voice-language assets. English voice assets are preloaded by the image; preload other voice languages before running offline. Restart the gateway after changing its ConfigMap, and restart data services after rotating their environment secrets.

Reference: [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) and [persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).
