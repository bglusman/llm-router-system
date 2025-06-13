# HomeHelper

HomeHelper aims to be a locally hosted voice assistant and LLM router with modular tool support.

This repository contains a minimal implementation skeleton. The goal is to allow experimenting with different speech-to-text (STT) engines, text-to-speech (TTS) engines, LLM backends, and integration with Home Assistant.

The services are orchestrated via `docker-compose`. See below for instructions.

## Running with Docker Compose

1. Install [Docker](https://docs.docker.com) and [Docker Compose](https://docs.docker.com/compose/).
2. From the repository root run:
   ```bash
   docker compose up --build
   ```
3. The router will be available on `http://localhost:8080/health`.

Models for Vosk and Llama are expected in the `models/` directory. The compose file mounts them into their respective containers.

See `docs/architecture.md` for a high level design and implementation roadmap.
