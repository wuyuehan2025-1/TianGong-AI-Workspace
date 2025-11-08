"""
Command line utilities for the Tiangong AI Workspace.

The CLI provides quick checks for local prerequisites (Python, uv, Node.js)
and lists the external AI tooling CLIs that this workspace integrates with.
Edit this file to tailor the workspace to your own toolchain.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable, Tuple

import typer

from . import __version__

app = typer.Typer(help="Tiangong AI Workspace CLI for managing local AI tooling.")

# (command, label) pairs for CLI integrations that the workspace cares about.
REGISTERED_TOOLS: Iterable[Tuple[str, str]] = (
    ("openai", "OpenAI CLI (Codex)"),
    ("gcloud", "Google Cloud CLI (Gemini)"),
    ("claude", "Claude Code CLI"),
)


def _get_version(command: str) -> str | None:
    """
    Return the version string for a CLI command if available.

    Many CLIs support `--version` and emit to stdout; others may use stderr.
    """
    try:
        result = subprocess.run(
            [command, "--version"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return None

    output = (result.stdout or result.stderr).strip()
    return output or None


@app.command()
def info() -> None:
    """Print a short summary of the workspace."""
    typer.echo(f"Tiangong AI Workspace v{__version__}")
    typer.echo("Unified CLI workspace for Codex, Gemini, and Claude Code automation.")
    typer.echo("")
    typer.echo(f"Project root : {Path.cwd()}")
    typer.echo(f"Python       : {sys.version.split()[0]} (requires >=3.12)")
    uv_path = shutil.which("uv")
    typer.echo(f"uv executable: {uv_path or 'not found in PATH'}")


@app.command("tools")
def list_tools() -> None:
    """List the external AI tooling CLIs tracked by the workspace."""
    typer.echo("Configured AI tooling commands:")
    for command, label in REGISTERED_TOOLS:
        typer.echo(f"- {label}: `{command}`")
    typer.echo("")
    typer.echo("Edit src/tiangong_ai_workspace/cli.py to customize this list.")


@app.command()
def check() -> None:
    """Validate local prerequisites such as Python, uv, Node.js, and AI CLIs."""
    typer.echo("Checking workspace prerequisites...\n")

    python_ok = sys.version_info >= (3, 12)
    python_status = "[OK]" if python_ok else "[WARN]"
    typer.echo(f"{python_status} Python {sys.version.split()[0]} (requires >=3.12)")

    uv_path = shutil.which("uv")
    uv_status = "[OK]" if uv_path else "[MISSING]"
    typer.echo(f"{uv_status} Astral uv: {uv_path or 'not found'}")

    node_path = shutil.which("node")
    if node_path:
        node_version = _get_version("node") or "version unknown"
        typer.echo(f"[OK] Node.js: {node_version} ({node_path})")
    else:
        typer.echo("[MISSING] Node.js: required for Node-based CLIs such as Claude Code")

    typer.echo("")
    typer.echo("AI coding toolchains:")
    for command, label in REGISTERED_TOOLS:
        location = shutil.which(command)
        status = "[OK]" if location else "[MISSING]"
        version = _get_version(command) if location else None
        detail = version or "not installed"
        typer.echo(f"{status} {label} ({command}): {location or detail}")

    typer.echo("")
    typer.echo("Update src/tiangong_ai_workspace/cli.py to adjust tool detection rules.")


def main() -> None:
    """Entry point for python -m execution."""
    app()


if __name__ == "__main__":
    main()
