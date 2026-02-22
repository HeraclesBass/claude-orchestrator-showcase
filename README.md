# V11 AI Agent Orchestration Framework

> A meta-orchestration system for coordinating 100+ specialized AI agents across a production microservices platform. Custom lifecycle hooks, spec-driven development, and wave-based parallel execution.

**Live at [herakles.dev](https://herakles.dev)** | **[Platform Architecture](https://github.com/HeraclesBass/portfolio)** | **[Contact](mailto:hello@herakles.dev)**

---

## Why This Exists

Managing dozens of microservices with a single-person team required rethinking how AI assistance scales. Instead of ad-hoc prompting, I built a structured orchestration layer that:

- **Routes tasks to specialists** — A meta-orchestrator analyzes intent and delegates to domain-specific agents
- **Enforces safety at scale** — Lifecycle hooks gate every file write, deployment, and destructive action
- **Parallelizes work** — Wave-based execution runs independent agents concurrently with dependency tracking
- **Maintains context** — Semantic memory persists architectural decisions across sessions
- **Self-improves** — Agent performance metrics inform routing decisions over time

This framework has managed **2,000+ development sessions** across **1,600+ verified hours** of production work.

---

## System Architecture

```
                         User Intent
                              |
                    +---------v---------+
                    |  Meta-Orchestrator |  Analyzes, plans, coordinates
                    |                    |  Risk-gated authorization
                    +----+----+----+----+
                         |    |    |
            +------------+    |    +------------+
            |                 |                 |
   +--------v-------+ +------v------+ +--------v--------+
   |  Spec Agents   | | Domain Agents| | Infrastructure  |
   |  (9 per ver.)  | | (60+ active) | | Agents          |
   |                | |              | |                 |
   | Planner        | | Frontend     | | Container Mgmt  |
   | Architect      | | Backend      | | Proxy Config    |
   | Implementer    | | Database     | | SRE             |
   | Integrator     | | Security     | | CI/CD           |
   | Tester         | | TypeScript   | | Deploy Mgmt     |
   | Security       | | AI/ML        | | Log Analysis     |
   | Optimizer      | | Mobile       | | System Mgmt      |
   | Reviewer       | | Real-time    | | Monitoring       |
   | Recovery       | | Docs         | |                 |
   +----------------+ +------+------+ +-----------------+
                              |
                    +---------v---------+
                    |  Skills Layer      |  Slash-command interface
                    |  48 commands       |  Auto-detection triggers
                    |  Hot-reload        |  No restart needed
                    +-------------------+
                              |
                    +---------v---------+
                    |  Lifecycle Hooks   |  Pre/Post tool execution
                    |  Advisory mode     |  Fail-closed enforcement
                    +-------------------+
                              |
                    +---------v---------+
                    |  External Services |  API integrations
                    |  (MCP protocol)    |  Scoped access
                    +-------------------+
```

---

## Agent Ecosystem

### 100+ Agents Across 16 Categories

| Category | Purpose |
|----------|---------|
| **Spec Orchestration** | Full-lifecycle project execution: plan, architect, implement, integrate, test, secure, optimize, review, recover |
| **Development** | Frontend, backend, TypeScript, database, real-time, documentation, mobile |
| **Security** | Vulnerability assessment, auth testing, API security, code review |
| **Infrastructure** | Container management, proxy configuration, SRE, monitoring, CI/CD |
| **Meta** | Agent architecture design, ecosystem optimization, capability management |
| **Professional** | Technical PM, migration strategy, comprehensive code review |
| **Design** | UI/UX with modern aesthetics and component systems |
| **Specialized** | Domain-specific tools for niche workflows |

### Three-Tier Model Assignment

```
Tier 1 (Reasoning)     High-capability model     Complex architecture, multi-step planning
Tier 2 (Execution)     Balanced model             Implementation, testing, standard tasks
Tier 3 (Speed)         Fast model                 Quick searches, simple validation, triage
```

Agents inherit their model from context by default. Critical agents (planners, orchestrators) are pinned to specific tiers for consistent reasoning quality.

### Agent Lifecycle

```
Registration       Central JSON registry with metadata
     |
Discovery          Keyword search + routing tables
     |
Invocation         Meta-orchestrator selects by task analysis
     |
Execution          Isolated context with scoped tool access
     |
Tracking           Per-invocation metrics log
     |             Consecutive failure detection -> escalation
Retirement         Deprecation flag, sync across formats
```

---

## Hook System

### Lifecycle Hooks

Every file write, deployment, and destructive action passes through the hook pipeline. Hooks are **advisory** — they inform and warn but never block execution, preventing false-positive deadlocks in multi-agent scenarios.

**Hook categories:**

| Category | Trigger | Purpose |
|----------|---------|---------|
| **Project detection** | File reads | Sets active project context automatically |
| **Write gates** | File modifications | Requires active task before changes |
| **Risk enforcement** | Writes, shell commands | Consolidated risk + authorization checks |
| **Effort calibration** | Agent spawning | Advises complexity level by keyword analysis |
| **Teammate health** | Task operations | Detects stalled agents with recovery suggestions |
| **Test enforcement** | Pre-deploy | Coverage threshold validation |
| **Syntax validation** | Post-write | Validates modified files automatically |
| **State sync** | Task operations | Centralized state tracking |
| **Agent metrics** | Post-spawn | Performance logging and escalation triggers |
| **Trust tracking** | Post-write/shell | Autonomy metric updates and audit logging |
| **Session lifecycle** | Session end | Metrics summary and cleanup |

### Performance

Measured across thousands of executions:
- Average P50 latency under 250ms
- 25-33% faster than the previous generation (consolidated from 19 hooks to 12)
- Zero production deadlocks due to advisory-only design

### Policy Enforcement

Tool access is controlled through a multi-level policy cascade:

```
Global defaults -> Formation overrides -> Agent-specific grants -> Runtime rules

Resolution: If ANY level denies -> denied (fail-closed)
```

Pre-built access profiles range from full (all tools) to minimal (read-only).

---

## Skills System

### 48 Skills with Hot-Reload

Skills are slash-command interfaces that wrap complex multi-step workflows. They auto-reload on file change — no process restart required.

| Category | Examples |
|----------|---------|
| **Development Lifecycle** | Project scaffolding, deployment, testing, debugging, rollback |
| **Observability** | Health dashboards, log analysis, service diagnostics |
| **Infrastructure** | Logging setup, proxy config, port management |
| **Session Management** | Status tracking, context handoff, session archival |
| **Specialized** | Domain-specific tools for security, reverse engineering, analysis |

### Skill Structure

```yaml
# YAML Frontmatter
name: deploy
version: 2.1.0
triggers:
  - /deploy
  - "push to prod"
model: balanced          # Cost-optimized model selection

# Markdown Body — protocol steps, validation, rollback
```

---

## Spec-Driven Development

### The Protocol

Instead of ad-hoc development, every non-trivial change follows a structured protocol:

```
Intent -> Spec -> Plan -> Execute -> Verify -> Archive

1. User states intent              "I want to add user auth"
2. Spec agent writes spec          Constraints, acceptance criteria, risks
3. Architect designs               Component diagram, API contracts, data model
4. Conductor plans waves           Parallel execution groups with dependencies
5. Implementers execute            Schema-validated task transitions
6. Testers verify                  Multi-level testing (unit -> regression)
7. Session archived                Searchable history with summaries
```

### Auto-Activation

The system detects when spec-driven mode is needed:
- Multiple services affected by a change
- Patterns like "I want to build...", "Add X to all services..."
- Architectural changes or cross-service migrations

### Task State Machine

```
                    +----------+
                    |  pending  |
                    +-----+----+
                          |
                    +-----v----+
                    |in_progress|---- Hook enforces: file writes
                    +-----+----+     require this state
                          |
              +-----------+-----------+
              |           |           |
        +-----v----+ +---v---+ +-----v----+
        |completed | |blocked| |  failed   |
        +----------+ +-------+ +-----+----+
                                      |
                              +-------v-------+
                              |Recovery Agent  |
                              |(auto-rollback) |
                              +---------------+
```

### Artifact Handoffs (V11)

Tasks pass structured artifacts to downstream tasks, eliminating redundant context loading:

```
Upstream task completes:
  -> files_changed: which files were modified
  -> api_contract: new/changed endpoints
  -> test_hints: what tests need updating
  -> breaking_changes: what downstream tasks should know

Result: 15x reduction in token overhead vs. agents re-reading entire codebases
```

---

## Team Formations

### 8 Pre-Built Patterns

| Formation | Use Case |
|-----------|----------|
| **New Project** | Greenfield development with full agent complement |
| **Feature Implementation** | Adding features to existing codebase |
| **Bug Investigation** | Root cause analysis and fix with recovery |
| **Security Review** | Vulnerability assessment and hardening |
| **Performance Optimization** | Profiling and tuning |
| **Code Review** | Quality gates and standards enforcement |
| **Single File** | Quick targeted changes |
| **Lightweight Feature** | Small features with fast iteration |

Formations encode proven agent combinations and tool access policies, eliminating per-task team composition decisions while ensuring consistent security boundaries.

### Formation Health

Active formations emit health signals at configurable intervals:
- Teammate status polling
- Stalled agent detection
- Resource usage tracking
- Automatic recovery suggestions

---

## Semantic Memory

### Hybrid Search

```
Query: "How does auth validate tokens?"

  Vector similarity search (embedding-based)
  + Keyword matching (full-text search)
  = Ranked results from project memory

Storage:    Per-project databases
Indexing:   Delta updates on task completion
Lifecycle:  Persists across sessions
```

Architectural decisions made weeks ago inform today's agent routing without re-discovery.

---

## Schema Validation

### 6 JSON Schemas (Draft 2020-12)

| Schema | Validates |
|--------|-----------|
| **Task metadata** | Artifact handoff structure between tasks |
| **Autonomy state** | Per-project permission levels |
| **Tool policy** | Tool group taxonomy and access profiles |
| **Memory index** | Semantic memory entry structure |
| **Formation config** | Team definitions with tool policies |
| **Formation registry** | Teammate file ownership tracking |

All schemas run in **advisory mode** — validation failures emit warnings but never block. This prevents false-positive deadlocks while maintaining data quality signals.

---

## Risk & Autonomy Model

### 5-Level Authorization

| Level | Scope | Gate |
|-------|-------|------|
| **A0** | Read-only operations | None |
| **A1** | Local file edits | Active task required |
| **A2** | Service restarts, deployments | Plan review + approval |
| **A3** | Infrastructure changes | Explicit approval required |
| **A4** | Destructive / production-wide | Approval + verification step |

Trust metrics accumulate over successful operations, enabling graduated autonomy grants per project.

---

## Version Evolution

```
V5  (2025)    Script-based automation
               Problem: Fragile scripts, no state management

V7  (2025)    Protocol-driven behavior, hook enforcement
               Added: Config-as-governance, project scaffolding

V8  (2026)    Tasks-as-truth, wave orchestration
               Added: 9 spec agents, 5-level autonomy, 80+ agents

V9  (2026)    Agent Teams, adaptive thinking
               Added: Consolidated hook architecture, native team API

V10 (2026)    Parallel spawning, extended metadata
               Added: Timeout protection, 8 formations

V11 (2026)    Artifact handoffs, adversarial verification
               Added: Semantic memory, tool policy cascade
               100+ agents, 48 skills, 6 schemas
```

Each version was driven by real production failures and measured performance regressions — not theoretical improvements.

---

## Design Decisions

### Why Advisory Hooks (Not Blocking)
Blocking hooks create false-positive deadlocks in multi-agent scenarios. Advisory mode ensures agents always make progress while maintaining full audit trails. Fail-closed enforcement provides safety without brittleness.

### Why Tasks-as-Truth (Not Chat History)
Chat context is ephemeral and lossy. Task state persists, supports dependency tracking, and enables artifact handoffs. Tasks are the single source of truth — not conversation history.

### Why Semantic Memory (Not Traditional RAG)
Traditional RAG requires document chunking and retrieval pipelines. Per-project databases with hybrid search give sub-second results with zero infrastructure overhead. Memory is indexed incrementally, not batch-processed.

### Why 100+ Specialized Agents (Not 5 General Ones)
Specialized agents with domain-specific system prompts outperform general agents on domain tasks. The routing overhead (keyword matching + registry lookup) is negligible compared to the quality improvement from focused expertise.

### Why Formation Patterns (Not Ad-Hoc Teams)
Pre-built formations encode proven agent combinations and access policies. This eliminates per-task team composition decisions and ensures consistent security boundaries.

---

## By the Numbers

| Metric | Value |
|--------|-------|
| Registered agents | 100+ (80 active) |
| Agent categories | 16 |
| Skills (slash-commands) | 48 with hot-reload |
| Lifecycle hooks | 12 (advisory mode) |
| JSON schemas | 6 |
| Team formations | 8 pre-built patterns |
| External integrations | MCP protocol |
| Development sessions | 2,000+ |
| Verified dev hours | 1,600+ |
| Protocol versions | 6 (V5 through V11) |

---

## For Recruiters

This framework demonstrates:

- **Systems architecture** — Designing scalable multi-agent coordination with clear separation of concerns
- **Production engineering** — Measured performance across thousands of executions, versioned protocols, backward compatibility
- **Security thinking** — Fail-closed authorization, multi-level policy enforcement, advisory-mode safety
- **Developer experience** — 48 skills with hot-reload, slash-command interface, auto-detection triggers
- **Iterative improvement** — 6 protocol versions driven by production metrics and real failure modes

### Architectural Patterns Used

- Event-driven agent communication
- Schema-validated state machines
- Multi-level policy cascade with fail-closed semantics
- Hybrid search (vector embeddings + keyword matching)
- Artifact handoffs for context propagation
- Formation patterns for team composition
- Advisory hooks for non-blocking safety enforcement
- Three-tier model assignment for cost/quality optimization

---

## For Collaborators

Interested in agent orchestration, spec-driven development, or AI-augmented engineering workflows? Happy to discuss architecture, share patterns, or explore collaboration.

**Contact**: [hello@herakles.dev](mailto:hello@herakles.dev) | [LinkedIn](https://www.linkedin.com/in/d-michael-piscitelli-2932a281/)

---

*Architecture showcase only. Source code is private. Built and operated by [D. Michael Piscitelli](https://github.com/HeraclesBass).*
