"""Run a .sql file against the Databricks SQL warehouse, one statement at a time.

Usage:
    uv run python scripts/run_sql.py sql/00_setup.sql

Settings come from environment variables, with defaults for this project:
    DATABRICKS_CONFIG_PROFILE  CLI profile in ~/.databrickscfg (default: blessing)
    DATABRICKS_WAREHOUSE_ID    SQL warehouse ID (default: the Serverless Starter Warehouse)
"""

import os
import sys
import time

from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementState

PROFILE = os.environ.get("DATABRICKS_CONFIG_PROFILE", "blessing")
WAREHOUSE_ID = os.environ.get("DATABRICKS_WAREHOUSE_ID", "a5a0d945b7ad7544")
DONE = {StatementState.SUCCEEDED, StatementState.FAILED, StatementState.CANCELED, StatementState.CLOSED}


def split_statements(sql: str) -> list[str]:
    """Split on semicolons at the end of a line, but not inside $$ ... $$ blocks
    (metric view YAML and SQL function bodies live inside $$)."""
    statements, current, in_dollar = [], [], False
    for line in sql.splitlines():
        if line.strip().startswith("--") and not in_dollar:
            continue
        current.append(line)
        in_dollar ^= line.count("$$") % 2 == 1
        if not in_dollar and line.rstrip().endswith(";"):
            statement = "\n".join(current).strip().rstrip(";").strip()
            if statement:
                statements.append(statement)
            current = []
    leftover = "\n".join(current).strip()
    if leftover:
        statements.append(leftover)
    return statements


def run(path: str) -> None:
    client = WorkspaceClient(profile=PROFILE)
    statements = split_statements(open(path).read())
    print(f"{path}: {len(statements)} statements on warehouse {WAREHOUSE_ID}")
    for i, statement in enumerate(statements, 1):
        first_line = statement.splitlines()[0][:80]
        print(f"[{i}/{len(statements)}] {first_line}")
        response = client.statement_execution.execute_statement(
            statement=statement, warehouse_id=WAREHOUSE_ID, wait_timeout="50s"
        )
        # A stopped serverless warehouse can take longer than 50s to start, so keep polling.
        while response.status.state not in DONE:
            time.sleep(3)
            response = client.statement_execution.get_statement(response.statement_id)
        if response.status.state != StatementState.SUCCEEDED:
            error = response.status.error
            sys.exit(f"FAILED: {error.error_code}: {error.message}" if error else f"FAILED: {response.status.state}")
        if response.result and response.result.data_array:
            for row in response.result.data_array[:20]:
                print("   ", row)
    print("All statements succeeded.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    run(sys.argv[1])
