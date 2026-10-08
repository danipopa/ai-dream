import json
import os
import shutil
import threading
import uuid
from pathlib import Path

import torch
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from starlette.background import BackgroundTask

from melo.api import TTS
from openvoice import se_extractor
from openvoice.api import ToneColorConverter


DATA_DIR = Path(os.getenv("VOICE_DATA_DIR", "/data"))
CHECKPOINT_DIR = Path(os.getenv("OPENVOICE_CHECKPOINT_DIR", "/models/checkpoints_v2"))
INTERNAL_TOKEN = os.getenv("VOICE_SERVICE_TOKEN", "")
MAX_SAMPLE_BYTES = int(os.getenv("MAX_SAMPLE_BYTES", str(25 * 1024 * 1024)))
DEVICE = os.getenv("VOICE_DEVICE", "cuda:0" if torch.cuda.is_available() else "cpu")
SUPPORTED_LANGUAGES = {"EN", "ES", "FR", "ZH", "JP", "KR"}

DATA_DIR.mkdir(parents=True, exist_ok=True)
(DATA_DIR / "voices").mkdir(exist_ok=True)
(DATA_DIR / "output").mkdir(exist_ok=True)

converter_dir = CHECKPOINT_DIR / "converter"
tone_converter = ToneColorConverter(str(converter_dir / "config.json"), device=DEVICE)
tone_converter.load_ckpt(str(converter_dir / "checkpoint.pth"))
tts_models: dict[str, TTS] = {}
inference_lock = threading.Lock()

app = FastAPI(title="ai-dream OpenVoice service", version="1.0.0")


class SpeechRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2500)
    language: str = "EN"
    speed: float = Field(default=1.0, ge=0.5, le=2.0)


def authorize(x_internal_token: str | None = Header(default=None)) -> None:
    if INTERNAL_TOKEN and x_internal_token != INTERNAL_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid internal service token")


def voice_dir(voice_id: str) -> Path:
    try:
        safe_id = str(uuid.UUID(voice_id))
    except ValueError as error:
        raise HTTPException(status_code=404, detail="Voice profile not found") from error
    path = DATA_DIR / "voices" / safe_id
    if not path.is_dir():
        raise HTTPException(status_code=404, detail="Voice profile not found")
    return path


def model_for(language: str) -> TTS:
    if language not in tts_models:
        tts_models[language] = TTS(language=language, device=DEVICE)
    return tts_models[language]


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "engine": "OpenVoice V2", "device": DEVICE, "license": "MIT"}


@app.post("/v1/voices", dependencies=[Depends(authorize)])
def create_voice(name: str = Form(...), sample: UploadFile = File(...)) -> dict:
    if not sample.content_type or not sample.content_type.startswith("audio/"):
        raise HTTPException(status_code=422, detail="The sample must be an audio file")

    profile_id = str(uuid.uuid4())
    profile_dir = DATA_DIR / "voices" / profile_id
    profile_dir.mkdir(parents=True)
    suffix = Path(sample.filename or "sample.wav").suffix.lower() or ".wav"
    sample_path = profile_dir / f"sample{suffix}"

    with sample_path.open("wb") as destination:
        shutil.copyfileobj(sample.file, destination)
    if sample_path.stat().st_size > MAX_SAMPLE_BYTES:
        shutil.rmtree(profile_dir)
        raise HTTPException(status_code=413, detail="Voice sample exceeds the size limit")

    try:
        with inference_lock:
            embedding, _ = se_extractor.get_se(
                str(sample_path), tone_converter, target_dir=str(profile_dir / "processed"), vad=True
            )
            torch.save(embedding.detach().cpu(), profile_dir / "embedding.pth")
        (profile_dir / "metadata.json").write_text(json.dumps({"name": name}), encoding="utf-8")
    except Exception as error:
        shutil.rmtree(profile_dir, ignore_errors=True)
        raise HTTPException(status_code=422, detail=f"Could not extract a voice profile: {error}") from error

    return {"voice_id": profile_id, "status": "ready"}


@app.post("/v1/speech/{voice_id}", dependencies=[Depends(authorize)])
def create_speech(voice_id: str, request: SpeechRequest) -> FileResponse:
    language = request.language.upper()
    if language not in SUPPORTED_LANGUAGES:
        raise HTTPException(status_code=422, detail=f"Unsupported language: {language}")

    profile_dir = voice_dir(voice_id)
    output_path = DATA_DIR / "output" / f"{uuid.uuid4()}.wav"
    source_path = DATA_DIR / "output" / f"{uuid.uuid4()}-source.wav"

    try:
        with inference_lock:
            model = model_for(language)
            speaker_ids = model.hps.data.spk2id
            preferred_speaker = os.getenv(f"OPENVOICE_{language}_SPEAKER", "EN-US" if language == "EN" else "")
            speaker_key = preferred_speaker if preferred_speaker in speaker_ids else next(iter(speaker_ids))
            speaker_id = speaker_ids[speaker_key]
            source_embedding_name = speaker_key.lower().replace("_", "-")
            source_embedding = torch.load(
                CHECKPOINT_DIR / "base_speakers" / "ses" / f"{source_embedding_name}.pth",
                map_location=DEVICE,
            )
            target_embedding = torch.load(profile_dir / "embedding.pth", map_location=DEVICE).to(DEVICE)

            model.tts_to_file(request.text, speaker_id, str(source_path), speed=request.speed, quiet=True)
            tone_converter.convert(
                audio_src_path=str(source_path),
                src_se=source_embedding,
                tgt_se=target_embedding,
                output_path=str(output_path),
                message="@MyShell",
            )
    except Exception as error:
        output_path.unlink(missing_ok=True)
        raise HTTPException(status_code=500, detail=f"Speech generation failed: {error}") from error
    finally:
        source_path.unlink(missing_ok=True)

    return FileResponse(
        output_path,
        media_type="audio/wav",
        filename="speech.wav",
        background=BackgroundTask(output_path.unlink, missing_ok=True),
    )
