---
name: indra-ocr
description: "Extrai texto de PDFs, imagens, prints e scans localmente com Indra OCR. Use sempre que o usuário pedir para ler, extrair, digitalizar ou converter PDF, foto, print ou scan para texto, markdown ou JSON, incluindo notas fiscais, contratos, artigos, recibos e documentos escaneados. Funciona offline, sem enviar arquivos para a nuvem. Palavras-chave: OCR, PDF, imagem, scan, digitalizar, extrair texto, nota fiscal, documento."
---

# Indra OCR

OCR local para PDFs e imagens. Roda em CPU via ONNX Runtime e não envia o documento para fora da máquina.

## Comando base

```sh
indra-ocr ARQUIVO [ARQUIVO...] [opções]
```

O padrão é markdown no stdout. Para gravar um arquivo por entrada:

```sh
indra-ocr documento.pdf --out resultados/
```

## Formatos

| Flag | Saída | Uso |
|---|---|---|
| `--format md` (padrão) | Markdown | Leitura humana, documentação, RAG |
| `--format text` | Texto puro | Colar em outro programa, diff |
| `--format json` | JSON por página | Caixas, confiança, blocos, timings |

O JSON traz `lines[].text`, `lines[].box`, `lines[].conf`, `blocks[]` e `markdown`, o que ajuda a depurar erros de leitura.

## Receitas

```sh
# PDF único
indra-ocr contrato.pdf

# Vários PDFs
indra-ocr *.pdf --out resultados/

# Foto ou print
indra-ocr foto.png --format text

# Scan ruim: força OCR e aumenta a resolução
indra-ocr scan.jpg --mode ocr --dpi 300

# PDF com senha
indra-ocr protegido.pdf --password 'senha'

# Só as 10 primeiras páginas
indra-ocr livro.pdf --max-pages 10

# PDF nativo, sem OCR
indra-ocr artigo.pdf --mode text

# Manter cabeçalhos e rodapés
indra-ocr relatorio.pdf --keep-furniture

# Fórmulas em LaTeX
indra-ocr paper.pdf --math

# Limitar CPU
indra-ocr lote/*.pdf --out saida/ --cores 4
```

## Como escolher o modo

- `--mode auto` (padrão): usa a camada de texto quando ela passa nas verificações e OCR onde não passa. É a melhor opção para a maioria dos PDFs.
- `--mode ocr`: ignora a camada de texto e OCRiza tudo. Use em scans, PDFs com texto quebrado ou quando o `auto` errar.
- `--mode text`: usa a camada de texto mesmo que as verificações falhem. Use em PDFs nativos e limpos; é mais rápido e preserva a ordem original.

## Limites e conferência

- Tabelas complexas e manuscritos são o ponto fraco. O texto sai, mas a estrutura pode se perder.
- Scans tortos, escuros ou de baixa resolução erram mais. Em PDFs escaneados, `--dpi 300` ajuda; se puder, endireite e aumente o contraste antes.
- O OCR pode omitir ou trocar caracteres em trechos ruins. Em documentos fiscais, jurídicos ou médicos, confira números, nomes e totais contra o original.
- `--cores N` limita o paralelismo; em máquina em uso, `--cores 4` evita travar tudo.
- A primeira execução baixa ~76 MB de modelos para `~/.cache/huggingface`.

## Integração

- Para resumir, classificar ou extrair campos estruturados, passe o markdown gerado para o modelo do harness.
- Para busca semântica sobre o texto extraído, use a skill `embeddinggemma`.
- Para PDFs muito grandes, processe em partes com `--max-pages` ou divida antes com `qpdf`/`pdfseparate`.

## Se o comando não existir

```sh
ls -l ~/.local/bin/indra-ocr
```

O comando é um symlink para `~/local-ai/indra/.venv/bin/indra-ocr`. Se o venv sumir, recrie com `uv` conforme o `~/local-ai/README.md`.
