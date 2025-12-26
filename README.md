# TianGong AI Workspace

## Project Overview
- General-purpose AI CLI workspace to manage Codex, Gemini CLI, Claude Code, and routine document authoring tasks in one place.
- Python dependencies are managed by `uv`; LangChain and LangGraph components are built in for fast extension.
- Provides the `tiangong-workspace` CLI: inspect environment info, run document workflows, trigger Tavily web research, call Crossref/OpenAlex metadata endpoints, and launch autonomous agents.
- Includes Tavily MCP search plus LangGraph autonomous agents that can browse the web, execute Shell/Python, and orchestrate LangChain workflows to handle open-ended tasks.
- Cross-platform install scripts cover Ubuntu, macOS, and Windows, with optional Node.js and Pandoc/MiKTeX.

## Directory Layout
- `install_*.sh` / `install_windows.ps1`: one-click installers.
- `src/tiangong_ai_workspace/`: workspace Python package and CLI entrypoint.
  - `cli.py`: Typer CLI with `docs`, `agents`, `research`, `crossref`, `openalex`, and `mcp` subcommands.
  - `agents/`: LangGraph document workflows (`workflows.py`), dual-engine autonomous agents for LangGraph/DeepAgents (`deep_agent.py`), and LangChain Tools with Pydantic input/output validation (`tools.py`).
  - `tooling/`: response envelope, workspace config loader (`config.py`), tool registry, model router (`llm.py`), shared tool schemas (`tool_schemas.py`), Tavily MCP client, Crossref Works API client (`crossref.py`), OpenAlex Works/Cited-by client (`openalex.py`), Dify knowledge-base client (`dify.py`), Neo4j client (`neo4j.py`), and audited Shell/Python executors.
  - `templates/`: structural prompts for different document types.
  - `mcp_client.py`: synchronous MCP client wrapper.
  - `secrets.py`: credential loader.
- `pyproject.toml`: project metadata and dependencies (manage with `uv add/remove`).
- `AGENTS.md` / `README.md`: collaboration guides for agents and users.

## Quick Install
1) Clone or download the repo.  
2) Run the OS-specific script (flags: `--full`, `--minimal`, `--with-pdf`, `--with-node`, etc.):

```bash
# Ubuntu
bash install_ubuntu.sh --full

# macOS
bash install_macos.sh --full

# Windows (from an elevated PowerShell)
PowerShell -ExecutionPolicy Bypass -File install_windows.ps1 -Full
```

The scripts check/install:
- Python 3.12+
- Astral `uv`
- Node.js 22+ (only when Node-based CLIs are needed)
- Pandoc + LaTeX/MiKTeX (optional, for PDF/DOCX export)

## Manual Install
If you prefer manual setup:

```bash
uv sync                 # install Python deps
uv run tiangong-workspace info
```

Activate the virtualenv with `source .venv/bin/activate` (Windows: `.venv\Scripts\activate`) if desired.

## CLI Usage
Common commands:

```bash
uv run tiangong-workspace --help
uv run tiangong-workspace info          # show version and paths
uv run tiangong-workspace check         # validate Python, uv, Node.js, and external CLIs
uv run tiangong-workspace tools         # list detected external CLIs
uv run tiangong-workspace tools --catalog   # list internal workflows and tool registry entries
uv run tiangong-workspace agents list       # list autonomous agents and runtime executors
uv run tiangong-workspace knowledge retrieve "query keywords"  # query the Dify knowledge base directly
uv run tiangong-workspace crossref journal-works "1234-5678" --query "LLM"
uv run tiangong-workspace openalex work "10.1016/S0921-3449(00)00060-4"
uv run tiangong-workspace openalex cited-by "W2072484418" --from 2020-01-01 --to 2021-01-01
uv run tiangong-workspace embeddings generate "example text"
```

All commands support `--json` for structured output that other agents can consume.

### Workspace Configuration
- `[tool.tiangong.workspace.cli_tools]` / `[tool.tiangong.workspace.tool_registry]` in `pyproject.toml` control CLI detection and the Agent Catalog—no source edits required.
- Registry tools automatically include input/output JSON Schemas; `tiangong-workspace tools --catalog` shows the full shapes for static validation.

## Autonomous Agents and Runtime Execution
The `agents` subcommand launches LangGraph-based multi-tool agents that can plan, call Shell/Python, browse with Tavily, and generate documents:

```bash
uv run tiangong-workspace agents run "Produce market research and an implementation plan for a new energy project"
uv run tiangong-workspace agents run "Summarize metrics in data.csv and plot them" --no-tavily
```

Default tools:
- Shell executor: runs CLI tools/scripts/`uv`/`git` with structured stdout/stderr.
- Python executor: runs scripts in a shared interpreter with `pandas`, `matplotlib`, `seaborn`, etc.
- Tavily search: real-time web research via MCP.
- Crossref: query `/journals/{issn}/works` for journal articles.
- OpenAlex: fetch metadata by DOI or cited-by counts within a date window.
- Dify knowledge base: direct HTTP access to a configured dataset without MCP.
- LangGraph document workflows: reports, plans, patent disclosures, project proposals.
- Neo4j graph database: run Cypher with create/read/update/delete helpers.
- OpenAI-compatible embeddings: call local or remote OpenAI-style services with structured JSON responses.

Use `--no-shell`, `--no-python`, `--no-tavily`, `--no-dify`, `--no-crossref`, `--no-openalex`, `--no-document` to disable tools; `--engine langgraph|deepagents` switches backends; `--system-prompt` and `--model` customize the agent.

## Document Workflows
The `docs` subcommand runs LangGraph workflows (research → outline → draft → optional AI review) for reports, plans, patent disclosures, project proposals, and more:

```bash
uv run tiangong-workspace docs list

uv run tiangong-workspace docs run report \
  --topic "Quarterly project summary" \
  --audience "R&D team and product leads" \
  --instructions "Highlight key metric changes and include action items"
```

Common flags:
- `--skip-research`: skip Tavily web search.
- `--search-query`: custom search keywords (default: topic).
- `--purpose`: model hint (`general`, `deep_research`, `creative`).
- `--language`: output language (default: Chinese).
- `--ai-review`: run an automated review after drafting and return actionable edits.

Successful runs return structured results; with `--ai-review`, review notes are included.

## Web Research
`research` calls the Tavily MCP tool directly:

```bash
uv run tiangong-workspace research "EV market share"
uv run tiangong-workspace research "AI writing assistants comparison" --json
```

Override MCP service or tool names with `--service` and `--tool-name` if needed.

## Crossref Literature
`crossref` accesses the Works API `/journals/{issn}/works` endpoint for journal metadata:

```bash
uv run tiangong-workspace crossref journal-works "1234-5678" \
  --query "large language model" \
  --filters '{"from-pub-date": "2023-01-01"}' \
  --rows 5 \
  --select '["title", "DOI", "author"]' \
  --mailto me@example.com
```

`--filters` accepts JSON objects/arrays or a raw Crossref filter string (e.g., `from-pub-date:2020-01-01,until-pub-date:2020-12-31`); `--select` accepts a JSON array or comma-separated fields. Include `--mailto` to follow Crossref best practices.

## OpenAlex Metadata/Citations
`openalex` provides quick metadata lookups and citation stats:

```bash
# Metadata by DOI
uv run tiangong-workspace openalex work "10.1016/S0921-3449(00)00060-4" --mailto me@example.com

# Cited-by counts within a date window (requires OpenAlex work_id, e.g., W2072484418)
uv run tiangong-workspace openalex cited-by "W2072484418" \
  --from 2000-09-01 \
  --to 2002-09-01 \
  --per-page 200 \
  --cursor "*"
```

`cited-by` uses `cites:work_id` plus `from/to_publication_date` to filter citing works by publication date; `meta.count` is the citation count for the window. Use cursors for deep pagination.

## Knowledge Base Retrieval
`knowledge` queries a Dify knowledge base directly over HTTP (no MCP needed):

```bash
# Tune retrieval strategy and semantic/keyword weights
uv run tiangong-workspace knowledge retrieve "data governance" --top-k 8 --search-method semantic_search --semantic-weight 0.35

# Combine reranking and metadata filters
uv run tiangong-workspace knowledge retrieve \
  "new energy" \
  --reranking \
  --reranking-provider openai \
  --reranking-model text-embedding-3-large \
  --metadata '{"logical_operator": "and", "conditions": [{"name": "doc_type", "comparison_operator": "eq", "value": "whitepaper"}]}'
```

The CLI emits a structured `WorkspaceResponse`; with `--json` it can be chained to other agents. In addition to `--options`, flags like `--search-method`, `--reranking/--no-reranking`, `--reranking-provider/--reranking-model`, `--score-threshold`, `--score-threshold-enabled/--no-score-threshold-enabled`, `--semantic-weight`, and `--metadata` assemble the Dify `retrieval_model` and `metadata_filtering_conditions` for precise control.

## Embeddings
`embeddings` calls the OpenAI-compatible service configured in `.sercrets/secrets.toml`:

```bash
# Basic example
uv run tiangong-workspace embeddings generate "Enterprise data governance plan"

# Batch texts + custom model + JSON output
uv run tiangong-workspace embeddings generate "text A" "text B" \
  --model Qwen/Qwen3-Embedding-0.6B \
  --json
```

Default output is a summary; `--json` returns a structured `WorkspaceResponse` with `embeddings`, `model`, `dimensions`, and `usage`, ready for vector workflows. For unauthenticated local models, set `api_key` to an empty string.

## Secrets Configuration
1) Copy `.sercrets/secrets.example.toml` to `.sercrets/secrets.toml` (keep it out of version control).
2) Fill `openai.api_key`; optionally set `model`, `chat_model`, and `deep_research_model`.
3) Add Tavily MCP settings, e.g.:

```toml
[tavily_web_mcp]
transport = "streamable_http"
service_name = "tavily"
url = "https://mcp.tavily.com/mcp"
api_key = "<YOUR_TAVILY_API_KEY>"
api_key_header = "Authorization"
api_key_prefix = "Bearer"
```

4) Add Neo4j connection info if needed (agents skip Neo4j when absent):

```toml
[neo4j]
uri = "bolt://localhost:7687"
username = "neo4j"
password = "<YOUR_NEO4J_PASSWORD>"
database = "neo4j"
```

5) To access a Dify knowledge base directly:

```toml
[dify_knowledge_base]
api_base_url = "https://thuenv.tiangong.world:7001/v1"
api_key = "dataset-XXXX"
dataset_id = "53a90891-853c-4bf0-bf39-96dd84e11501"
```

6) To enable OpenAI-compatible embedding generation (local/private services supported), add:

```toml
[openai_compatitble_embedding]
url = "http://192.168.1.140:8004/v1/"
api_key = ""
model = "Qwen/Qwen3-Embedding-0.6B"
```

## Custom Integrations
1) Add/modify CLI checks in `[tool.tiangong.workspace.cli_tools]` within `pyproject.toml` to reflect immediately in `tiangong-workspace tools`.  
2) Register new internal tools via `[tool.tiangong.workspace.tool_registry]` or `tooling/registry.py`; `tools --catalog` will expose them with JSON Schemas.  
3) Build new tools or executors in `agents/tools.py` / `tooling/executors.py`, and wire them into LangGraph/DeepAgents via `agents/deep_agent.py`.  
4) Extend LangGraph workflows or add templates under `agents/` for more writing scenarios.  
5) Keep `AGENTS.md` and `README.md` in sync with any code changes.

## Development Notes
- Dependency management: use `uv add <package>` / `uv remove <package>`.
- After any code change, always run and pass in order:

```bash
uv run black .
uv run ruff check
uv run pytest
```

- Run tests with `uv run pytest`.
- Any code changes require updating this file and `AGENTS.md`.

## License
This project is licensed under the [MIT License](LICENSE).
