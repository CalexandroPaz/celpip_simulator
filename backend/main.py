"""
CELPIP Simulator — Backend FastAPI (Fase 5)

Instalar dependencias:
    pip install fastapi uvicorn python-multipart openai

Correr localmente:
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

Desde el emulador Android, la app accede en: http://10.0.2.2:8000
Desde iOS Simulator:                           http://127.0.0.1:8000
Desde dispositivo físico en red local:         http://<IP_LAN>:8000
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="CELPIP Simulator API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

# ─── Modelos ─────────────────────────────────────────────────────────────────

SectionName = Literal["listening", "reading", "writing", "speaking"]


class AnswerPayload(BaseModel):
    question_id: str
    answered_at: str
    type: Literal["multipleChoice", "text", "audio"]
    # multipleChoice
    selected_index: int | None = None
    # text
    text: str | None = None
    # audio (solo metadatos; el archivo llega como UploadFile en /score/speaking)
    recording_path: str | None = None


class ScoreRequest(BaseModel):
    section: SectionName
    answers: list[AnswerPayload]


class ScoreResponse(BaseModel):
    section: SectionName
    raw_score: float | None
    celpip_band: str | None
    pending: bool = False


# ─── Correctas de referencia (cargadas desde JSON en producción) ──────────────

# En producción, leer correctAnswerIndex del mismo JSON del examen.
# Aquí se usa un diccionario estático a modo de ejemplo.
CORRECT_ANSWERS: dict[str, int] = {
    # Listening
    "L1-Q1": 2, "L1-Q2": 0, "L1-Q3": 1,
    "L2-Q1": 3, "L2-Q2": 1,
    "L3-Q1": 0, "L3-Q2": 2, "L3-Q3": 1,
    # Reading
    "R1-Q1": 1, "R1-Q2": 3, "R1-Q3": 0,
    "R2-Q1": 2, "R2-Q2": 1,
    "R3-Q1": 0, "R3-Q2": 3, "R3-Q3": 1,
}


def _band_from_raw(raw: float) -> str:
    if raw >= 90:
        return "12"
    if raw >= 80:
        return "11"
    if raw >= 70:
        return "10"
    if raw >= 60:
        return "9"
    return "8"


# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/api/v1/score", response_model=ScoreResponse)
async def score_section(request: ScoreRequest) -> ScoreResponse:
    """Scoring automático para Listening, Reading y Writing."""

    if request.section in ("listening", "reading"):
        answers = request.answers
        correct = sum(
            1
            for a in answers
            if a.type == "multipleChoice"
            and CORRECT_ANSWERS.get(a.question_id) == a.selected_index
        )
        total = max(len(answers), 1)
        raw = (correct / total) * 100.0
        return ScoreResponse(
            section=request.section,
            raw_score=round(raw, 1),
            celpip_band=_band_from_raw(raw),
        )

    if request.section == "writing":
        # TODO: llamar a OpenAI / Claude para evaluar los textos.
        # Por ahora devuelve pendiente.
        return ScoreResponse(
            section="writing",
            raw_score=None,
            celpip_band=None,
            pending=True,
        )

    # Speaking sin audio no debería llegar a este endpoint.
    return ScoreResponse(
        section=request.section,
        raw_score=None,
        celpip_band=None,
        pending=True,
    )


@app.post("/api/v1/score/speaking", response_model=ScoreResponse)
async def score_speaking(
    section: str = Form(...),
    answers_json: str = Form(...),
    # FastAPI recibe todos los campos de audio como lista de UploadFile.
    # En producción se mapean por nombre: audio_S1, audio_S2, ...
) -> ScoreResponse:
    """
    Scoring de Speaking con archivos de audio adjuntos.

    Cada archivo de audio se recibe como campo multipart con nombre
    audio_<questionId> (ej. audio_S1, audio_S2).

    TODO: transcribir con Whisper y evaluar con Claude/GPT.
    """
    answers = json.loads(answers_json)  # noqa: F841

    # TODO: guardar archivos temporalmente y pasar a Whisper para transcripción.
    # Ejemplo de cómo acceder a los archivos:
    #   for answer in answers:
    #       qid = answer["question_id"]
    #       audio_file = <el UploadFile con nombre audio_{qid}>
    #       with tempfile.NamedTemporaryFile(suffix=".m4a") as f:
    #           f.write(await audio_file.read())
    #           transcript = await transcribe(f.name)

    # Devuelve pendiente hasta integrar el evaluador de IA.
    return ScoreResponse(
        section="speaking",
        raw_score=None,
        celpip_band=None,
        pending=True,
    )


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
