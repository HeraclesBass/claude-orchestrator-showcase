# V11 Agent Orchestration Framework

Architecture for coordinating 100+ AI agents through lifecycle hooks, JSON schemas, and wave-based parallel execution. Built on Claude Code with custom meta-orchestration.

## How It Works

The orchestrator receives a user request and decomposes it into a set of tasks, each annotated with risk level, complexity, and scope via the task-metadata schema. Tasks are grouped into waves -- parallel execution batches with dependency ordering -- and assigned to specialist agents organized into formations. Lifecycle hooks enforce quality gates at each stage: project detection on session start, syntax validation before commits, and agent tracking throughout execution.

## Schemas

Define the data contracts for the orchestration system (JSON Schema Draft 2020-12):

| Schema | Purpose |
|--------|---------|
| `task-metadata` | Task state, artifact handoffs, verification status |
| `formation-config` | Agent team composition and role assignments |
| `formation-registry` | Available formations and their capabilities |
| `tool-policy` | Per-tool authorization rules (allow/deny/confirm) |
| `autonomy-state` | 5-level agent autonomy tracking (L1 supervised to L5 autonomous) |
| `memory-index` | Semantic memory organization across sessions |

## Hooks

Lifecycle scripts that enforce quality gates during agent execution:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `detect-project` | Session start | Identifies project type from directory structure |
| `verify-syntax` | Pre-commit | Validates spec files and configuration |
| `track-agents` | Agent spawn/complete | Monitors agent lifecycle and coordination |

Shared utilities in `hooks/lib/common.sh`.

## Examples

Documented workflows showing the framework in action:

- **Session Planning** -- Full planning phase with task decomposition and wave assignment
- **Implementation Workflow** -- Code generation with artifact handoffs between agents
- **Integration Testing** -- Multi-service test orchestration with health checks

## Architecture

```
User Request
  |
  v
Orchestrator (meta-agent)
  |
  +-- Decompose --> Tasks (task-metadata.schema)
  |
  +-- Assign --> Formations (formation-config.schema)
  |     |
  |     +-- Wave 1: [agent-a, agent-b]  <- parallel
  |     +-- Wave 2: [agent-c]           <- sequential
  |     +-- Wave 3: [agent-d, agent-e]  <- parallel
  |
  +-- Enforce --> Hooks (detect, verify, track)
  |
  +-- Gate --> Tool Policies (tool-policy.schema)
               Autonomy Levels (autonomy-state.schema)
```

## Key Concepts

- **Formations** -- Named agent team compositions (e.g., `feature-impl`: architect + implementer + tester)
- **Waves** -- Parallel execution groups with dependency ordering
- **Autonomy levels** -- L1 (every action confirmed) through L5 (fully autonomous)
- **Artifact handoffs** -- Typed outputs passed between agents across waves (files changed, API contracts, test hints, breaking changes)
- **Tool policies** -- Per-tool allow/deny/confirm rules enforced by hooks via a multi-level cascade

---

*Architecture showcase. Source code is private. Built by [D. Michael Piscitelli](https://github.com/HeraclesBass).*
