---
name: parakeet
description: "Transcreve áudio e vídeo localmente com Parakeet Redux. Use sempre que o usuário pedir para transcrever, converter fala em texto, gerar legendas, atas ou resumos de reunião, podcast, aula, entrevista ou vídeo. Inclui timestamps por palavra, detecção de silêncio (VAD) e servidor local compatível com a API de transcrição da OpenAI. Palavras-chave: transcrever, transcrição, áudio, vídeo, podcast, reunião, legenda, ASR, speech-to-text."
---

# Parakeet

Transcrição local de fala com Parakeet Redux, rodando em CPU pelo `parakeet.cpp`. O áudio não sai da máquina.

## Preparar o áudio

O CLI só aceita WAV. Converta vídeo ou áudio compactado antes:

```sh
# vídeo
ffmpeg -i entrada.mp4 -vn -ac 1 -ar 16000 audio.wav

# áudio
ffmpeg -i entrada.mp3 -ac 1 -ar 16000 audio.wav
```

16 kHz mono é o formato esperado pelo modelo e reduz o tempo de processamento.

## Transcrever

```sh
parakeet transcribe --input audio.wav
```

Para o modelo padrão, o wrapper já injeta o modelo e as bibliotecas; não passe `--model`.

```sh
# Timestamps por palavra (início-fim, palavra, confiança)
parakeet transcribe --input audio.wav --timestamps

# JSON com texto e words[]
parakeet transcribe --input audio.wav --json

# Ignorar silêncios
parakeet transcribe --input audio.wav --vad

# Áudio em português
parakeet transcribe --input audio.wav --lang pt

# Limitar threads
parakeet transcribe --input audio.wav --threads 4
```

`--timestamps` imprime uma linha por palavra:

```text
0.32-0.56  Well,  (0.99)
0.64-0.80  I  (1.00)
```

`--json` devolve `text`, `frame_sec` e `words[]` com `w`, `start`, `end` e `conf`.

## Servidor compatível com OpenAI

Para manter o modelo carregado e atender vários pedidos:

```sh
parakeet-server --port 8304
```

O endpoint é `POST /v1/audio/transcriptions` e aceita apenas WAV:

```sh
curl -s http://127.0.0.1:8304/v1/audio/transcriptions \
  -F file=@audio.wav

curl -s http://127.0.0.1:8304/v1/audio/transcriptions \
  -F file=@audio.wav \
  -F response_format=text
```

O wrapper abre automaticamente o componente `asr` do bundle. Para usar outro modelo, passe `--model` e, se for um bundle, `--component NOME`.

`--concurrency K` atende K transcrições em paralelo; mantenha `K x threads` dentro do número de núcleos físicos.

## Receitas

```sh
# Vídeo local
ffmpeg -i video.mp4 -vn -ac 1 -ar 16000 audio.wav
parakeet transcribe --input audio.wav --vad --timestamps

# Podcast longo
ffmpeg -i episodio.mp3 -ac 1 -ar 16000 episodio.wav
parakeet transcribe --input episodio.wav --vad

# Só um trecho
ffmpeg -ss 00:10:00 -to 00:20:00 -i reuniao.mp4 -vn -ac 1 -ar 16000 trecho.wav
parakeet transcribe --input trecho.wav
```

## Limites e conferência

- Nomes próprios, siglas, números e jargões erram mais. Confira antes de publicar atas ou legendas.
- Ruído, música e várias pessoas falando ao mesmo tempo pioram bastante.
- O VAD pula silêncio, mas não divide o áudio. Para gravações longas, corte em blocos de 10–20 minutos se o processo ficar pesado.
- O modelo é multilíngue, mas o desempenho varia por idioma. Valide uma amostra antes de rodar horas de gravação.
- O servidor devolve `"language":"en"` no `verbose_json` por limitação do código atual; ignore esse campo e use o texto.
- A primeira execução carrega o modelo por alguns segundos; o servidor evita esse custo repetido.

## Verificação

```sh
command -v parakeet parakeet-server
parakeet info ~/local-ai/models/parakeet-bundle-moondream-redux.gguf
```

Se o binário reclamar de biblioteca, use os wrappers de `~/.local/bin`, que configuram `LD_LIBRARY_PATH`.
