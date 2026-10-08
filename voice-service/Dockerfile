FROM pytorch/pytorch:2.2.2-cuda12.1-cudnn8-runtime

ARG OPENVOICE_REF=main
ARG MELOTTS_REF=main

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/models/huggingface \
    OPENVOICE_CHECKPOINT_DIR=/models/checkpoints_v2

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ffmpeg git git-lfs libavdevice-dev libavformat-dev libsndfile1 pkg-config && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/myshell-ai/OpenVoice.git /opt/OpenVoice && \
    cd /opt/OpenVoice && git checkout "$OPENVOICE_REF" && \
    git clone https://github.com/myshell-ai/MeloTTS.git /opt/MeloTTS && \
    cd /opt/MeloTTS && git checkout "$MELOTTS_REF"

RUN pip install "cython<3" "numpy==1.22.0" && \
    pip install --no-build-isolation -e /opt/OpenVoice && \
    pip install --no-build-isolation -e /opt/MeloTTS && \
    python -m unidic download

RUN git lfs install && \
    git clone https://huggingface.co/myshell-ai/OpenVoiceV2 /models/checkpoints_v2 && \
    python -c "import torch; torch.hub.load('snakers4/silero-vad', 'silero_vad', trust_repo=True)" && \
    python -c "from melo.api import TTS; TTS(language='EN', device='cpu')"

# NLTK 3.9+ renamed the English tagger used by MeloTTS. A real warm-up sentence
# also pulls the lazily-loaded BERT text model into the image for offline use.
RUN python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng', raise_on_error=True); nltk.download('cmudict', raise_on_error=True); from melo.api import TTS; model = TTS(language='EN', device='cpu'); model.tts_to_file('Offline model warm up.', model.hps.data.spk2id['EN-US'], '/tmp/warmup.wav', quiet=True)" && \
    rm -f /tmp/warmup.wav

# Initializing the converter downloads wavmark's small auxiliary model. Cache it
# during the build instead of requiring outbound access on container startup.
RUN python -c "from openvoice.api import ToneColorConverter; converter = ToneColorConverter('/models/checkpoints_v2/converter/config.json', device='cpu'); converter.load_ckpt('/models/checkpoints_v2/converter/checkpoint.pth')"

COPY requirements-api.txt /tmp/requirements-api.txt
RUN pip install -r /tmp/requirements-api.txt

WORKDIR /service
COPY app /service/app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
