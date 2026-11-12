# opencode-config

Configuração pessoal do [OpenCode](https://opencode.ai) versionada sem segredos: modelo, MCPs, plugins, preferências da TUI e skills locais.

## Estrutura

```
.
├── config/
│   ├── opencode.json       # modelo, MCPs e plugins
│   ├── cli.json            # tema, keybinds e preferências da TUI
│   └── opencode-mem.jsonc  # config do plugin opencode-mem
├── skills/                 # 8 skills locais
├── install.sh              # backup + symlinks em ~/.config/opencode
└── .gitignore
```

## Instalação

```sh
git clone <URL_DO_REPO> ~/opencode-config
cd ~/opencode-config
./install.sh --dry-run   # confere o que será feito
./install.sh
```

O `install.sh`:

1. move as configs existentes para `~/.config/opencode/backup-<timestamp>-<pid>/`;
2. symlinka `config/*` e `skills/` em `~/.config/opencode`;
3. cria `~/.config/opencode/secrets/` com permissão `700`.

É idempotente: rodar de novo só refaz os links (sem backup de links).

## Segredos (não versionados)

| Item | Como recriar |
|---|---|
| PAT do GitHub | `mkdir -p ~/.config/opencode/secrets && printf '%s' 'ghp_...' > ~/.config/opencode/secrets/github-pat && chmod 600 ~/.config/opencode/secrets/github-pat` |
| `service.json` | gerado automaticamente pelo OpenCode; não versionar |
| Dados do `opencode-mem` | ficam em `~/.opencode-mem/data` |

O `config/opencode.json` referencia o PAT como `{file:~/.config/opencode/secrets/github-pat}` — o token em si nunca entra no repo.

## MCPs

| Nome | Tipo | Endereço/comando |
|---|---|---|
| `context7` | remote | `https://mcp.context7.com/mcp` |
| `github` | remote | `https://api.githubcopilot.com/mcp/` (Bearer via arquivo do PAT) |
| `playwright` | local | `npx -y @playwright/mcp@latest --executable-path <chromium>` |
| `rea` | local | `npx -y rea-agents@6.9.0 mcp` (provider Ghidra) |

**Ajuste por máquina:** o caminho do Chromium do Playwright e o `GHIDRA_INSTALL_DIR` (`/opt/ghidra`) são específicos deste setup. Em outra máquina, edite `config/opencode.json` antes de instalar. O REA usa Ghidra 12.1.x/12.2 via `REA_ANALYSIS_PROVIDER=ghidra`.

## Plugins

| Plugin | Origem |
|---|---|
| `superpowers` | `git+https://github.com/obra/superpowers.git` |
| `opencode-mem` | pacote `opencode-mem` (memória vetorial local via Turso/libSQL) |

O OpenCode instala os plugins declarados em `opencode.json`; não é preciso vendorizar `node_modules`.

## Skills incluídas

| Skill | Função |
|---|---|
| `embeddinggemma` | embeddings e similaridade semântica local |
| `frontend-design` | direção visual para UI |
| `grilling` | stress-test de planos e ideias |
| `grill-me` | atalho manual para `grilling` |
| `handoff` | resumo da conversa para outra sessão |
| `indra-ocr` | OCR local de PDF/imagem |
| `parakeet` | transcrição local de áudio/vídeo |
| `sudo-fingerprint` | comandos root via terminal da TUI |

## Skills externas (não versionadas)

Estas vivem em `~/.agents/skills` e são carregadas pelo OpenCode, mas não fazem parte deste repo:

- `understand`, `understand-chat`, `understand-dashboard`, `understand-diff`, `understand-domain`, `understand-explain`, `understand-figma`, `understand-knowledge`, `understand-onboard` — symlinks para `~/.understand-anything/repo/understand-anything-plugin/skills/`;
- `agent-reach`, `reverse-engineer-anything`, `skill-creator`, `vercel-react-best-practices`, `webapp-testing`, `web-design-guidelines` — instaladas separadamente em `~/.agents/skills/`.

## Atualizando

Depois de instalado, `~/.config/opencode/{opencode.json,cli.json,opencode-mem.jsonc}` e `~/.config/opencode/skills/` são symlinks para este repo. Edite normalmente e commite:

```sh
cd ~/opencode-config
git add -A
git commit -m "config: ..."
```

## Nota

O arquivo `~/opencode.json` (config de projeto no home) não faz parte deste repo.
