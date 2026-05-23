---
name: forget
description: Delete ferrex memories by ID
argument-hint: id1 [id2 id3 ...]
---

Delete memories from ferrex using the `ferrex__forget` MCP tool.

**Parse arguments** as space-separated memory IDs.

**Before deleting:** Show a summary of each memory (via the `ferrex__recall` MCP tool with the IDs if needed) and ask for confirmation.

**Call** the `ferrex__forget` MCP tool with `ids: [<parsed IDs>]`.

**Confirm** deletion count and IDs removed.
