---
name: embeddinggemma
description: "Gera embeddings de texto e calcula similaridade semântica localmente com EmbeddingGemma 2. Use para busca semântica, ranquear itens, encontrar documentos parecidos, deduplicar descrições, agrupar textos e alimentar RAG, inclusive matching de CATMAT no cotacao-ia. Palavras-chave: embedding, similaridade, busca semântica, vetor, dedup, ranquear, match, RAG, clusterizar."
---

# EmbeddingGemma 2

Encoder de texto local (270M, 768 dimensões) para similaridade e busca semântica. Roda em CPU e não chama API.

## CLI

```sh
embed sim "consulta" "documento 1" "documento 2" ...
embed search "consulta" arquivo.txt [-k 5]
embed encode "texto" ...
```

### Comparar uma consulta com documentos

```sh
embed sim "parafuso de aço inox" \
  "Nota fiscal de compra de parafusos de aço inox" \
  "Preço unitário de parafuso sextavado M8" \
  "Previsão do tempo para amanhã"
```

A saída vem ordenada por similaridade de cosseno:

```text
0.8592  Nota fiscal de compra de parafusos de aço inox
0.7616  Preço unitário de parafuso sextavado M8
0.5317  Previsão do tempo para amanhã
```

### Ranquear linhas de um arquivo

Cada linha não vazia vira um documento:

```sh
embed search "parafuso M8" catalogo.txt -k 5
```

### Gerar vetores em JSONL

```sh
embed encode "texto para virar vetor"
printf '%s\n' "primeira linha" "segunda linha" | embed encode -
```

Cada linha de saída é um JSON com `text` e `embedding` (768 floats).

## Como interpretar os scores

- Os vetores são normalizados; o score é similaridade de cosseno.
- Ranqueamento relativo é mais confiável que um limiar absoluto. Compare os candidatos entre si.
- Referência empírica neste modelo: ~0,85 para quase-duplicata, ~0,75 para mesmo assunto e ~0,53 para assunto diferente. Calibre com seus dados antes de fixar um corte.
- Para dedup, use um limiar alto (ex.: 0,92) e revise os pares entre 0,85 e 0,92.

## Prefixos de tarefa

O modelo foi treinado com prefixos. O CLI já aplica:

- consulta: `task: search result | query: `
- documento: `title: none | text: `

Se usar Python direto, aplique os mesmos prefixos. Não misture texto com e sem prefixo na mesma comparação.

## Python

Use o Python do venv, que já tem torch CPU, sentence-transformers, Pillow e torchvision:

```sh
~/local-ai/embeddinggemma/.venv/bin/python script.py
```

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer(
    "google/embeddinggemma-2",
    config_kwargs={"vision_config": None, "audio_config": None},
)

q = model.encode(
    "task: search result | query: parafuso M8",
    normalize_embeddings=True,
)
d = model.encode(
    [
        "title: none | text: parafuso sextavado M8",
        "title: none | text: previsão do tempo",
    ],
    normalize_embeddings=True,
)
print(model.similarity(q, d))
```

## Dedup em lote

O CLI carrega o modelo a cada execução (~6 s). Para lotes grandes, carregue uma vez e processe tudo no mesmo processo:

```python
import numpy as np
from sentence_transformers import SentenceTransformer

model = SentenceTransformer(
    "google/embeddinggemma-2",
    config_kwargs={"vision_config": None, "audio_config": None},
)

texts = [
    "parafuso sextavado M8 aço inox",
    "parafuso sextavado M8 inox",
    "previsão do tempo para amanhã",
]
vecs = model.encode(
    [f"title: none | text: {t}" for t in texts],
    normalize_embeddings=True,
)

sims = vecs @ vecs.T
np.fill_diagonal(sims, -1)
for i, j in zip(*np.where(sims > 0.92)):
    if i < j:
        print(f"{sims[i, j]:.3f}\t{texts[i]}\t{texts[j]}")
```

## Casos de uso

- **Matching CATMAT**: comparar a descrição de um item de edital com descrições do catálogo e ranquear candidatos.
- **Dedup**: encontrar descrições quase idênticas antes de importar uma planilha.
- **Busca semântica**: indexar documentos e recuperar os mais relevantes para uma pergunta.
- **Clusterização**: agrupar textos por assunto usando os vetores.
- **RAG**: recuperar trechos relevantes para alimentar um modelo gerador.

## Limites

- É texto apenas nesta instalação; não serve para similaridade de imagens ou áudio.
- Textos muito curtos (uma palavra) ou com muita sigla têm menos contexto. Inclua marca, unidade e especificação quando possível.
- Para catálogos grandes, gere os embeddings uma vez e guarde em JSONL, `.npy` ou banco vetorial em vez de recalcular.
- A primeira execução baixa ~1,5 GB de pesos para `~/.cache/huggingface`.

## Verificação

```sh
command -v embed
embed sim "teste" "teste de similaridade" "previsão do tempo"
```
