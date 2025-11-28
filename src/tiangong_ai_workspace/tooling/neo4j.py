"""
Neo4j client utilities and LangChain tool helpers.

This module wraps the official Neo4j Python driver so that workspace agents can
issue CRUD-style Cypher statements while keeping connection details inside the
local secrets file. The helper exposes a minimal API that returns plain Python
structures, making it easy to plug into LangChain tool definitions and CLI
commands.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Mapping, MutableMapping, Optional

from neo4j import READ_ACCESS, WRITE_ACCESS, Driver, GraphDatabase
from neo4j.exceptions import Neo4jError

from ..secrets import Neo4jSecrets, Secrets, load_secrets

__all__ = ["Neo4jClient", "Neo4jToolError"]

_OPERATION_ACCESS = {
    "create": WRITE_ACCESS,
    "update": WRITE_ACCESS,
    "delete": WRITE_ACCESS,
    "read": READ_ACCESS,
}


class Neo4jToolError(RuntimeError):
    """Raised when the Neo4j integration encounters a runtime failure."""


@dataclass(slots=True)
class Neo4jClient:
    """Lightweight Neo4j driver wrapper used by workspace tools."""

    config: Optional[Neo4jSecrets] = None
    secrets: Optional[Secrets] = None
    driver: Optional[Driver] = None
    _database: str | None = field(init=False, default=None, repr=False)

    def __post_init__(self) -> None:
        config = self.config
        if self.driver is not None:
            object.__setattr__(self, "_database", getattr(config, "database", None))
            return

        config = config or self._load_config_from_secrets()
        try:
            driver = GraphDatabase.driver(config.uri, auth=(config.username, config.password))
        except Exception as exc:  # pragma: no cover - driver raises rich types we normalise
            raise Neo4jToolError(f"Unable to initialise Neo4j driver: {exc}") from exc

        object.__setattr__(self, "config", config)
        object.__setattr__(self, "driver", driver)
        object.__setattr__(self, "_database", config.database)

    def close(self) -> None:
        """Close the underlying Neo4j driver, ignoring secondary failures."""

        driver = self.driver
        if driver is None:
            return
        try:
            driver.close()
        except Exception:  # pragma: no cover - best-effort cleanup
            pass

    def execute(
        self,
        statement: str,
        *,
        parameters: Mapping[str, Any] | None = None,
        operation: str = "read",
        database: str | None = None,
    ) -> Mapping[str, Any]:
        """Run a Cypher statement and return serialisable records + summary."""

        stmt = statement.strip()
        if not stmt:
            raise Neo4jToolError("Cypher statement cannot be empty.")

        access_mode, op_name = self._access_mode_for(operation)
        driver = self.driver
        if driver is None:
            raise Neo4jToolError("Neo4j driver is not initialised.")

        session_kwargs: MutableMapping[str, Any] = {}
        db_name = database or self._database
        if db_name:
            session_kwargs["database"] = db_name
        session_kwargs["default_access_mode"] = access_mode

        params = dict(parameters or {})

        try:
            with driver.session(**session_kwargs) as session:
                result = session.run(stmt, params)
                records = [record.data() for record in result]
                summary_obj = result.consume()
        except Neo4jToolError:
            raise
        except Neo4jError as exc:
            raise Neo4jToolError(f"Neo4j query failed: {exc}") from exc
        except Exception as exc:  # pragma: no cover - driver surfaces many custom errors
            raise Neo4jToolError(str(exc)) from exc

        summary = self._serialise_summary(summary_obj)
        payload: MutableMapping[str, Any] = {
            "records": records,
            "summary": summary,
            "operation": op_name,
        }
        if db_name:
            payload["database"] = db_name
        return payload

    def _access_mode_for(self, operation: str) -> tuple[Any, str]:
        op = (operation or "read").strip().lower()
        if op not in _OPERATION_ACCESS:
            allowed = ", ".join(sorted(_OPERATION_ACCESS))
            raise Neo4jToolError(f"Unsupported Neo4j operation '{operation}'. Allowed values: {allowed}.")
        return _OPERATION_ACCESS[op], op

    def _load_config_from_secrets(self) -> Neo4jSecrets:
        try:
            secrets = self.secrets or load_secrets()
        except FileNotFoundError as exc:
            raise Neo4jToolError(str(exc)) from exc
        config = getattr(secrets, "neo4j", None)
        if not config:
            raise Neo4jToolError("Neo4j credentials are missing. Add a [neo4j] section to secrets.toml.")
        return config

    def _serialise_summary(self, summary: Any) -> Mapping[str, Any] | None:
        if not summary:
            return None

        payload: MutableMapping[str, Any] = {}
        query = getattr(summary, "query", None)
        if query is not None:
            payload["query"] = getattr(query, "text", str(query))

        for attr in ("database", "query_type", "result_available_after", "result_consumed_after"):
            value = getattr(summary, attr, None)
            if value is not None:
                payload[attr] = value

        counters = getattr(summary, "counters", None)
        counter_data = self._serialise_counters(counters)
        if counter_data:
            payload["counters"] = counter_data

        return payload or None

    def _serialise_counters(self, counters: Any) -> Mapping[str, Any] | None:
        if counters is None:
            return None
        payload: MutableMapping[str, Any] = {}
        for attr in dir(counters):
            if attr.startswith("_"):
                continue
            value = getattr(counters, attr)
            if callable(value):
                continue
            if isinstance(value, (bool, int)):
                payload[attr] = value
        return payload or None
