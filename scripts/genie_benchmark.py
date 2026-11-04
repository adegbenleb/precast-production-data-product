"""Ask the Genie benchmark questions and print each answer, the SQL Genie wrote and the result rows.

Usage:
    uv run python scripts/genie_benchmark.py <space_id> [question_number ...]

Each question runs in its own new conversation, so earlier answers cannot influence later ones.
Expected answers are in genie/benchmarks.md.
"""

import os
import sys

from databricks.sdk import WorkspaceClient
from databricks.sdk.errors import OperationFailed

PROFILE = os.environ.get("DATABRICKS_CONFIG_PROFILE", "blessing")

QUESTIONS = {
    1: "How many elements did each plant produce?",
    2: "What is the scrap rate by plant?",
    3: "What is the rework rate for Plant B?",
    4: "Which plant has the lowest on-time delivery rate, and what is it?",
    5: "How did Plant C's average cycle time change from May to October 2026?",
}


def ask(client: WorkspaceClient, space_id: str, number: int) -> None:
    question = QUESTIONS[number]
    print(f"\n=== Q{number}: {question}")
    waiter = client.genie.start_conversation(space_id, question)
    try:
        message = waiter.result()
    except OperationFailed:
        # Record why Genie failed instead of crashing the whole run.
        message = client.genie.get_message(space_id, waiter.conversation_id, waiter.message_id)
        print(f"FAILED: status={message.status} error={message.error}")
    for attachment in message.attachments or []:
        if attachment.text:
            print(f"Answer: {attachment.text.content.strip()}")
        if attachment.query:
            print(f"SQL:\n{attachment.query.query.strip()}")
            if message.status and message.status.value != "COMPLETED":
                continue
            result = client.genie.get_message_attachment_query_result(
                space_id, message.conversation_id, message.message_id, attachment.attachment_id
            )
            data = result.statement_response.result
            for row in (data.data_array if data and data.data_array else [])[:15]:
                print(f"    {row}")
    if message.error:
        print(f"Error: {message.error}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    space = sys.argv[1]
    numbers = [int(n) for n in sys.argv[2:]] or sorted(QUESTIONS)
    workspace = WorkspaceClient(profile=PROFILE)
    for n in numbers:
        ask(workspace, space, n)
