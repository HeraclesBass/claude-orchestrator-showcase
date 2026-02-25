#!/bin/bash
# V11 Hook Library — shared constants and functions sourced by all hooks.

# Constants
HERCULES_ROOT="${HERCULES_ROOT:-/home/user}"
SESSIONS_ROOT="${SESSIONS_ROOT:-$HERCULES_ROOT/sessions}"
METRICS_DIR="$HERCULES_ROOT/.agent-metrics"
TASK_STATE_DIR="$METRICS_DIR/task-state"
REGISTRY_FILE="$METRICS_DIR/project-paths.json"
ACTIVE_PROJECT_FILE="$METRICS_DIR/active-project"

# Infrastructure dirs excluded from project detection
NON_PROJECTS="v11 v10 v9 v8 v7 v6_Ultra sessions scripts system-apps-config portfolio-platform \
.claude .agent-metrics .agent-registry .secrets .archive .cache .local .npm .nvm .config \
.ssh snap node_modules deploy.sh"

# Parse hook stdin JSON once into global vars.
v11_parse_input() {
  V11_RAW_INPUT="$(cat)"
  V11_TOOL_NAME="$(printf '%s' "$V11_RAW_INPUT"  | jq -r '.tool_name // empty')"
  V11_FILE_PATH="$(printf '%s' "$V11_RAW_INPUT"  | jq -r '.tool_input.file_path // .tool_input.path // empty')"
  V11_COMMAND="$(printf '%s' "$V11_RAW_INPUT"     | jq -r '.tool_input.command // empty')"
  V11_SESSION_ID="$(printf '%s' "$V11_RAW_INPUT"  | jq -r '.session_id // empty')"
  V11_TOOL_OUTPUT="$(printf '%s' "$V11_RAW_INPUT" | jq -r '.tool_output // empty')"
  V11_ERROR="$(printf '%s' "$V11_RAW_INPUT"       | jq -r '.error // empty')"

  # Backward-compatible aliases (hooks still reference V9_ names during migration)
  V9_RAW_INPUT="$V11_RAW_INPUT"
  V9_TOOL_NAME="$V11_TOOL_NAME"
  V9_FILE_PATH="$V11_FILE_PATH"
  V9_COMMAND="$V11_COMMAND"
  V9_SESSION_ID="$V11_SESSION_ID"
  V9_TOOL_OUTPUT="$V11_TOOL_OUTPUT"
  V9_ERROR="$V11_ERROR"
}

# Classify risk: prints "high", "medium", or "low".
v11_risk_level() {
  local tool="$V11_TOOL_NAME" cmd="$V11_COMMAND"
  # High-risk: destructive system/data/git operations
  if [[ "$cmd" =~ rm[[:space:]]+-r[f]|rm[[:space:]]+-fr ]] \
  || [[ "$cmd" =~ DROP[[:space:]]+(DATABASE|TABLE)|TRUNCATE|DELETE[[:space:]]+FROM ]] \
  || [[ "$cmd" =~ docker[[:space:]]+system[[:space:]]+prune[[:space:]]+-a ]] \
  || [[ "$cmd" =~ docker[[:space:]]+volume[[:space:]]+rm ]] \
  || [[ "$cmd" =~ git[[:space:]]+push[[:space:]]+--force|git[[:space:]]+push[[:space:]]+-f ]] \
  || [[ "$cmd" =~ git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]]+-f ]] \
  || [[ "$cmd" =~ shutdown|reboot|mkfs|dd[[:space:]]+if= ]] \
  || [[ "$cmd" =~ chown[[:space:]]+-R|chmod[[:space:]]+-R[[:space:]]+777 ]] \
  || [[ "$cmd" =~ \>[[:space:]]*/dev/sda ]]; then
    echo "high"; return
  fi
  # Medium-risk: file writes, or bash with stateful commands
  if [[ "$tool" == "Write" || "$tool" == "Edit" ]]; then
    echo "medium"; return
  fi
  if [[ "$tool" == "Bash" ]] \
  && [[ "$cmd" =~ (^|[[:space:]])(rm|git|docker|npm|pip)[[:space:]] ]]; then
    echo "medium"; return
  fi
  echo "low"
}

# Detect project name from file path (pure regex, no I/O).
# Sets V11_PROJECT and V11_DETECTION_METHOD.
v11_detect_project() {
  local filepath="${1:-$V11_FILE_PATH}"
  V11_PROJECT="" V11_DETECTION_METHOD=""
  # Convention 1: sessions/{name}/
  if [[ "$filepath" =~ ^$SESSIONS_ROOT/([^/]+) ]]; then
    V11_PROJECT="${BASH_REMATCH[1]}" V11_DETECTION_METHOD="sessions"; return
  fi
  # Convention 2: portfolio-platform/apps/{name}/
  if [[ "$filepath" =~ ^$HERCULES_ROOT/portfolio-platform/apps/([^/]+) ]]; then
    V11_PROJECT="${BASH_REMATCH[1]}" V11_DETECTION_METHOD="portfolio-app"; return
  fi
  # Convention 3: $HERCULES_ROOT/{name}/ (excluding infra dirs)
  if [[ "$filepath" =~ ^$HERCULES_ROOT/([^/]+) ]]; then
    local candidate="${BASH_REMATCH[1]}"
    for np in $NON_PROJECTS; do
      [[ "$candidate" == "$np" ]] && return
    done
    V11_PROJECT="$candidate" V11_DETECTION_METHOD="hercules-root"
  fi

  # Backward-compatible aliases
  V9_PROJECT="$V11_PROJECT"
  V9_DETECTION_METHOD="$V11_DETECTION_METHOD"
}

# Check if path is a metadata/infra file hooks should skip.
# Returns 0 (skip) or 1 (process).
v11_is_metadata_file() {
  local filepath="${1:-$V11_FILE_PATH}" base="${1:-$V11_FILE_PATH}"
  base="${base##*/}"
  # Infrastructure paths
  [[ "$filepath" == */v11/hooks/* || "$filepath" == */v9/hooks/* || "$filepath" == */.agent-metrics/* || "$filepath" == */.claude/* ]] && return 0
  # Known metadata filenames
  case "$base" in
    state.md|spec.md|gates.md|.task-state.json|.autonomy-state|.plan-mode-state) return 0 ;;
    .gitignore|CLAUDE.md) return 0 ;;
  esac
  # Env and backup files
  [[ "$base" == .env || "$base" == .env.* ]] && return 0
  [[ "$base" == *.json.backup* || "$base" == *.md.backup* ]] && return 0
  return 1
}

# Check risk level and apply autonomy grants for enforcement.
# Returns 0 if allowed, 2 if blocked.
# Used by guard-enforcement hook.
v11_check_risk() {
  local RISK="$(v11_risk_level)"

  # Low risk always allowed
  [ "$RISK" != "high" ] && return 0

  # High-risk pattern identification
  local MATCHED_PATTERN="" RISK_DESCRIPTION=""

  declare -A PATTERNS=(
    ["rm -rf"]="Recursive force delete"
    ["rm -fr"]="Recursive force delete"
    ["DROP DATABASE"]="Database deletion"
    ["DROP TABLE"]="Table deletion"
    ["TRUNCATE"]="Table truncation"
    ["DELETE FROM"]="Data deletion"
    ["docker system prune -a"]="Delete all Docker images"
    ["docker volume rm"]="Docker volume deletion"
    ["git push --force"]="Force push to remote"
    ["git push -f"]="Force push to remote"
    ["git reset --hard"]="Hard reset (loses commits)"
    ["git clean -f"]="Force clean untracked files"
    ["shutdown"]="System shutdown/reboot"
    ["reboot"]="System shutdown/reboot"
    ["mkfs"]="Format filesystem"
    ["dd if="]="Direct disk write"
    ["chown -R"]="Recursive ownership change"
    ["chmod -R 777"]="Dangerous permission change"
  )

  for PATTERN in "${!PATTERNS[@]}"; do
    if echo "$V11_COMMAND" | grep -qiF "$PATTERN"; then
      MATCHED_PATTERN="$PATTERN"
      RISK_DESCRIPTION="${PATTERNS[$PATTERN]}"
      break
    fi
  done

  if [ -z "$MATCHED_PATTERN" ]; then
    MATCHED_PATTERN="(unrecognized high-risk pattern)"
    RISK_DESCRIPTION="Destructive operation detected by risk classifier"
  fi

  # Check A4 auto-approval (project-local autonomy state)
  local AUTONOMY_FILE=""
  v11_detect_project "$V11_FILE_PATH"
  if [ -n "$V11_PROJECT" ] && [ -f "$SESSIONS_ROOT/$V11_PROJECT/.autonomy-state" ]; then
    AUTONOMY_FILE="$SESSIONS_ROOT/$V11_PROJECT/.autonomy-state"
  elif [ -n "$V11_PROJECT" ] && [ -f "$HERCULES_ROOT/$V11_PROJECT/.autonomy-state" ]; then
    AUTONOMY_FILE="$HERCULES_ROOT/$V11_PROJECT/.autonomy-state"
  fi

  if [ -n "$AUTONOMY_FILE" ] && [ -f "$AUTONOMY_FILE" ]; then
    local LEVEL="$(jq -r '.level // 0' "$AUTONOMY_FILE" 2>/dev/null)"

    if [ "$LEVEL" -ge 4 ] 2>/dev/null; then
      # Exact pattern match
      if jq -e --arg p "$MATCHED_PATTERN" \
          '.high_risk_history // [] | any(. == $p)' \
          "$AUTONOMY_FILE" >/dev/null 2>&1; then
        echo "[$(date -Iseconds)] HIGH RISK AUTO-APPROVED (A4): $MATCHED_PATTERN — $V11_COMMAND" \
            >> "$METRICS_DIR/autonomy-changes.log"
        return 0
      fi

      # Prefix match
      local CMD_PREFIX="$(echo "$V11_COMMAND" | awk '{print $1" "$2" "$3}')"
      if jq -e --arg p "$CMD_PREFIX" \
          '.high_risk_history // [] | any(startswith($p))' \
          "$AUTONOMY_FILE" >/dev/null 2>&1; then
        echo "[$(date -Iseconds)] HIGH RISK AUTO-APPROVED (A4 prefix): $CMD_PREFIX — $V11_COMMAND" \
            >> "$METRICS_DIR/autonomy-changes.log"
        return 0
      fi
    fi
  fi

  # Block with message
  local CURRENT_LEVEL="?"
  if [ -n "$AUTONOMY_FILE" ] && [ -f "$AUTONOMY_FILE" ]; then
    CURRENT_LEVEL="$(jq -r '.level // 0' "$AUTONOMY_FILE" 2>/dev/null)"
  fi

  cat <<EOF
HIGH RISK OPERATION BLOCKED

Risk Level: HIGH
Operation: $RISK_DESCRIPTION
Pattern: $MATCHED_PATTERN
Command: $V11_COMMAND

Current Autonomy Level: A$CURRENT_LEVEL
Note: A4 with history can auto-approve high-risk actions.

This operation can cause data loss or system damage.
To proceed, get explicit user approval.
EOF

  return 2
}

# Check autonomy grants for medium-risk operations.
# Returns 0 if auto-approved, 1 if needs user approval.
# Used by guard-enforcement hook.
v11_check_autonomy() {
  local RISK=$(v11_risk_level)

  # Low risk always allowed
  [ "$RISK" == "low" ] && return 0

  # High risk handled by v11_check_risk
  [ "$RISK" == "high" ] && return 0

  # Medium risk - check autonomy level
  local AUTONOMY_STATE=""

  # Detect project for project-specific autonomy
  v11_detect_project "$V11_FILE_PATH"
  if [ -z "$V11_PROJECT" ] && [ -n "$V11_COMMAND" ]; then
    local CMD_PATH=$(printf '%s' "$V11_COMMAND" | grep -oE "$HERCULES_ROOT/[^ ]+" | head -1)
    [ -n "$CMD_PATH" ] && v11_detect_project "$CMD_PATH"
  fi

  # Load autonomy state (project-specific only, no global fallback)
  if [ -n "$V11_PROJECT" ] && [ -f "$SESSIONS_ROOT/$V11_PROJECT/.autonomy-state" ]; then
    AUTONOMY_STATE=$(cat "$SESSIONS_ROOT/$V11_PROJECT/.autonomy-state" 2>/dev/null)
  fi

  # No project detected OR no state file → default to A0 (manual mode)
  # This is safe: guard-risk will handle blocking if needed
  [ -z "$AUTONOMY_STATE" ] && return 1

  local LEVEL=$(printf '%s' "$AUTONOMY_STATE" | jq -r '.level // 0' 2>/dev/null)
  [ -z "$LEVEL" ] || [ "$LEVEL" == "null" ] && LEVEL=0

  # A3+: all medium auto-approved
  if [ "$LEVEL" -ge 3 ]; then
    echo "Autonomy A3: all medium-risk auto-approved"
    return 0
  fi

  # A2: check grants for file pattern match
  if [ "$LEVEL" -ge 2 ] && [ -n "$V11_FILE_PATH" ]; then
    while IFS= read -r grant; do
      [ -z "$grant" ] || [ "$grant" == "null" ] && continue
      local PATTERN=$(printf '%s' "$grant" | jq -r '.pattern // empty')
      local GTYPE=$(printf '%s' "$grant" | jq -r '.type // "glob"')
      [ -z "$PATTERN" ] && continue

      case "$GTYPE" in
        glob)
          # shellcheck disable=SC2053
          if [[ "$V11_FILE_PATH" == $PATTERN ]]; then
            echo "Autonomy A2: grant matched $PATTERN"
            return 0
          fi
          ;;
        regex)
          if printf '%s' "$V11_FILE_PATH" | grep -qE "$PATTERN" 2>/dev/null; then
            echo "Autonomy A2: grant matched regex $PATTERN"
            return 0
          fi
          ;;
        prefix)
          if [[ "$V11_FILE_PATH" == "$PATTERN"* ]]; then
            echo "Autonomy A2: grant matched prefix $PATTERN"
            return 0
          fi
          ;;
      esac
    done < <(printf '%s' "$AUTONOMY_STATE" | jq -c '.grants // [] | .[]' 2>/dev/null)
  fi

  # A1: check approved_categories
  if [ "$LEVEL" -ge 1 ]; then
    local CATEGORY=""
    if [ -n "$V11_FILE_PATH" ]; then
      local EXT="${V11_FILE_PATH##*.}"
      case "$EXT" in
        ts|tsx|js|jsx) CATEGORY="typescript" ;;
        py)            CATEGORY="python" ;;
        sh|bash)       CATEGORY="shell" ;;
        md)            CATEGORY="markdown" ;;
        json|yaml|yml) CATEGORY="config" ;;
      esac
    elif [ -n "$V11_COMMAND" ]; then
      case "$V11_COMMAND" in
        git\ *)                    CATEGORY="git" ;;
        docker\ *)                 CATEGORY="docker" ;;
        npm\ *|yarn\ *|pnpm\ *)   CATEGORY="npm" ;;
      esac
    fi

    if [ -n "$CATEGORY" ]; then
      local MATCH=$(printf '%s' "$AUTONOMY_STATE" | jq -e \
          --arg c "$CATEGORY" '.approved_categories // [] | any(. == $c)' 2>/dev/null)
      if [ "$MATCH" == "true" ]; then
        echo "Autonomy A1: category '$CATEGORY' pre-approved"
        return 0
      fi
    fi
  fi

  # No matching grant - needs approval
  return 1
}

# Check file ownership in Agent Teams context.
# Validates that current agent can write this file based on .formation-registry.json.
# Returns 0 if allowed, 1 if blocked (conflict).
# Used by guard-write-gates hook.
v11_check_file_ownership() {
  local file_path="$1"
  local current_agent_id="${V11_AGENT_ID:-unknown}"

  # Early exit if no registry (not in Agent Team)
  [ ! -f ".formation-registry.json" ] && return 0

  # Validate JSON structure
  if ! jq empty ".formation-registry.json" >/dev/null 2>&1; then
    echo "WARNING: Invalid .formation-registry.json, skipping ownership check" >&2
    return 0
  fi

  # Extract all teammates
  local teammates
  teammates=$(jq -r '.teammates | keys[]' ".formation-registry.json" 2>/dev/null)

  # Check each teammate's ownership
  while IFS= read -r role; do
    [ -z "$role" ] && continue

    local owner_id
    owner_id=$(jq -r ".teammates[\"$role\"].agent_id" ".formation-registry.json" 2>/dev/null)

    # Check exact file match
    if jq -e --arg fp "$file_path" ".teammates[\"$role\"].ownership.files | map(. == \$fp) | any" \
       ".formation-registry.json" >/dev/null 2>&1; then
      if [ "$owner_id" != "$current_agent_id" ]; then
        cat >&2 <<EOF
FILE OWNERSHIP CONFLICT: $file_path
  Owner: $role (agent_id: $owner_id)
  Attempted write by: agent_id: $current_agent_id

Coordinate via task or update .formation-registry.json ownership.
EOF
        return 1
      fi
      return 0
    fi

    # Check directory match (file path starts with owned directory)
    if jq -e --arg fp "$file_path" ".teammates[\"$role\"].ownership.directories | map(. as \$dir | (\$fp | startswith(\$dir))) | any" \
       ".formation-registry.json" >/dev/null 2>&1; then
      if [ "$owner_id" != "$current_agent_id" ]; then
        cat >&2 <<EOF
FILE OWNERSHIP CONFLICT: $file_path
  Owner: $role (agent_id: $owner_id)
  Attempted write by: agent_id: $current_agent_id

Coordinate via task or update .formation-registry.json ownership.
EOF
        return 1
      fi
      return 0
    fi

    # Check glob patterns (basic implementation using bash patterns)
    local patterns
    patterns=$(jq -r ".teammates[\"$role\"].ownership.patterns[]" ".formation-registry.json" 2>/dev/null)
    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      # Enable globstar for ** matching
      shopt -s globstar extglob
      # shellcheck disable=SC2053
      if [[ "$file_path" == $pattern ]]; then
        if [ "$owner_id" != "$current_agent_id" ]; then
          cat >&2 <<EOF
FILE OWNERSHIP CONFLICT: $file_path
  Owner: $role (agent_id: $owner_id)
  Pattern matched: $pattern
  Attempted write by: agent_id: $current_agent_id

Coordinate via task or update .formation-registry.json ownership.
EOF
          return 1
        fi
        return 0
      fi
    done <<< "$patterns"
  done <<< "$teammates"

  # File not owned by anyone (new file) - allow with info
  echo "INFO: File $file_path is not assigned to any teammate (new file allowed)" >&2
  return 0
}

# --- V11: Artifact Handoff Functions ---

# Inject upstream artifacts from completed blocking tasks into context.
# Reads task_artifacts from project state file for tasks in blockedBy list.
# Usage: v11_inject_upstream_artifacts PROJECT BLOCKED_BY_IDS...
# Output: JSON array of upstream artifacts on stdout.
v11_inject_upstream_artifacts() {
  local project="$1"
  shift
  local blocked_by_ids=("$@")

  local state_file="$TASK_STATE_DIR/${project}.json"
  [ ! -f "$state_file" ] && echo "[]" && return 0

  local result="[]"
  for task_id in "${blocked_by_ids[@]}"; do
    local arts
    arts=$(jq -r --arg id "$task_id" '.task_artifacts[$id] // empty' "$state_file" 2>/dev/null)
    if [ -n "$arts" ] && [ "$arts" != "null" ]; then
      # Load external artifact_refs content if referenced
      local expanded_arts="$arts"
      local ref_count
      ref_count=$(printf '%s' "$arts" | jq '.artifact_refs | length' 2>/dev/null)
      if [ "${ref_count:-0}" -gt 0 ]; then
        expanded_arts=$(printf '%s' "$arts" | jq --arg sess "$SESSIONS_ROOT/$project" '
          .artifact_refs = [.artifact_refs[] | . + {
            "content_available": (($sess + "/" + .path) | test("^/") and true)
          }]
        ' 2>/dev/null)
      fi

      result=$(printf '%s' "$result" | jq \
        --arg id "$task_id" \
        --argjson arts "${expanded_arts:-$arts}" '
        . + [{"task_id": $id, "artifacts": $arts}]
      ')
    fi
  done

  printf '%s' "$result"
}

# Store a large artifact externally and return an artifact_ref object.
# Artifacts >2KB use external storage per V11 convention.
# Usage: v11_store_artifact_ref PROJECT TASK_ID NAME CONTENT [SUMMARY]
# Output: JSON artifact_ref object on stdout.
v11_store_artifact_ref() {
  local project="$1" task_id="$2" name="$3" content="$4" summary="${5:-}"

  local artifact_dir="$SESSIONS_ROOT/$project/artifacts/$task_id"
  mkdir -p "$artifact_dir"

  local artifact_path="$artifact_dir/$name"
  printf '%s' "$content" > "$artifact_path"

  local size_bytes
  size_bytes=$(wc -c < "$artifact_path")

  local rel_path="sessions/$project/artifacts/$task_id/$name"

  jq -n \
    --arg name "$name" \
    --arg path "$rel_path" \
    --arg summary "${summary:-$name}" \
    --argjson size "$size_bytes" \
    '{"name": $name, "path": $path, "summary": $summary, "size_bytes": $size}'
}

# Read an artifact from external storage by its ref.
# Usage: v11_read_artifact_ref ARTIFACT_REF_JSON
# Output: File contents on stdout.
v11_read_artifact_ref() {
  local ref_json="$1"

  local rel_path
  rel_path=$(printf '%s' "$ref_json" | jq -r '.path // empty')
  [ -z "$rel_path" ] && return 1

  local full_path="$HERCULES_ROOT/$rel_path"
  [ ! -f "$full_path" ] && return 1

  cat "$full_path"
}

# Ensure artifact directory exists for a project/task.
# Usage: v11_ensure_artifact_dir PROJECT TASK_ID
# Output: Path to artifact directory on stdout.
v11_ensure_artifact_dir() {
  local project="$1" task_id="$2"
  local dir="$SESSIONS_ROOT/$project/artifacts/$task_id"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# --- V11: Schema Validation Functions ---

V11_SCHEMA_DIR="${V11_SCHEMA_DIR:-$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/schemas}"

# Validate JSON data against a JSON Schema.
# Uses ajv-cli if available, falls back to jq structural checks.
# Returns 0 if valid, 1 if invalid (with errors on stderr).
# Usage: v11_validate_json JSON_STRING SCHEMA_NAME
#   JSON_STRING: The JSON to validate (string, not file path)
#   SCHEMA_NAME: Schema filename in schemas/ (e.g., "task-metadata.schema.json")
v11_validate_json() {
  local json_data="$1" schema_name="$2"
  local schema_file="$V11_SCHEMA_DIR/$schema_name"

  # Schema file must exist
  if [ ! -f "$schema_file" ]; then
    echo "WARN: Schema not found: $schema_file" >&2
    return 0  # Missing schema = pass (advisory mode)
  fi

  # Try ajv-cli first (full JSON Schema validation)
  if command -v ajv >/dev/null 2>&1; then
    local tmpfile
    tmpfile=$(mktemp /tmp/v11-validate-XXXXXX.json)
    printf '%s' "$json_data" > "$tmpfile"
    local result
    result=$(ajv validate -s "$schema_file" -d "$tmpfile" 2>&1)
    local rc=$?
    rm -f "$tmpfile"
    if [ $rc -ne 0 ]; then
      echo "SCHEMA VALIDATION FAILED ($schema_name):" >&2
      echo "$result" >&2
    fi
    return $rc
  fi

  # Fallback: jq structural validation (checks required fields and enums)
  v11_validate_json_jq "$json_data" "$schema_name"
}

# Lightweight jq-based validation fallback.
# Checks: valid JSON, required fields, enum constraints.
# Does NOT validate: conditional schemas (allOf/if-then), patterns, refs.
v11_validate_json_jq() {
  local json_data="$1" schema_name="$2"
  local errors=""

  # Must be valid JSON
  if ! printf '%s' "$json_data" | jq empty 2>/dev/null; then
    echo "SCHEMA VALIDATION FAILED: Invalid JSON" >&2
    return 1
  fi

  case "$schema_name" in
    task-metadata.schema.json)
      # Required: project, sprint, risk
      local project sprint risk
      project=$(printf '%s' "$json_data" | jq -r '.project // empty')
      sprint=$(printf '%s' "$json_data" | jq -r '.sprint // empty')
      risk=$(printf '%s' "$json_data" | jq -r '.risk // empty')

      [ -z "$project" ] && errors="${errors}Missing required field: project\n"
      [ -z "$sprint" ] && errors="${errors}Missing required field: sprint\n"
      [ -z "$risk" ] && errors="${errors}Missing required field: risk\n"

      # Enum: risk
      if [ -n "$risk" ] && [[ ! "$risk" =~ ^(low|medium|high)$ ]]; then
        errors="${errors}Invalid risk value: '$risk' (must be low|medium|high)\n"
      fi

      # Enum: complexity (if present)
      local complexity
      complexity=$(printf '%s' "$json_data" | jq -r '.complexity // empty')
      if [ -n "$complexity" ] && [[ ! "$complexity" =~ ^(novel|complex|medium|routine)$ ]]; then
        errors="${errors}Invalid complexity: '$complexity' (must be novel|complex|medium|routine)\n"
      fi

      # Enum: scope (if present)
      local scope
      scope=$(printf '%s' "$json_data" | jq -r '.scope // empty')
      if [ -n "$scope" ] && [[ ! "$scope" =~ ^(small|medium|large)$ ]]; then
        errors="${errors}Invalid scope: '$scope' (must be small|medium|large)\n"
      fi

      # Contradiction: routine + medium/high risk
      if [ "$complexity" = "routine" ] && [[ "$risk" =~ ^(medium|high)$ ]]; then
        errors="${errors}Contradiction: routine complexity + $risk risk (recategorize)\n"
      fi

      # High risk requires complexity + scope
      if [ "$risk" = "high" ]; then
        [ -z "$complexity" ] && errors="${errors}High risk requires complexity field\n"
        [ -z "$scope" ] && errors="${errors}High risk requires scope field\n"
      fi
      ;;

    formation-registry.schema.json)
      local formation project teammates
      formation=$(printf '%s' "$json_data" | jq -r '.formation // empty')
      project=$(printf '%s' "$json_data" | jq -r '.project // empty')
      teammates=$(printf '%s' "$json_data" | jq -r '.teammates // empty')

      [ -z "$formation" ] && errors="${errors}Missing required field: formation\n"
      [ -z "$project" ] && errors="${errors}Missing required field: project\n"
      [ "$teammates" = "" ] || [ "$teammates" = "null" ] && errors="${errors}Missing required field: teammates\n"

      # Teammate count: 1-5
      local count
      count=$(printf '%s' "$json_data" | jq '.teammates | length' 2>/dev/null)
      if [ "${count:-0}" -gt 5 ]; then
        errors="${errors}Too many teammates: $count (max 5)\n"
      fi
      ;;

    autonomy-state.schema.json)
      local level
      level=$(printf '%s' "$json_data" | jq -r '.level // empty')
      [ -z "$level" ] && errors="${errors}Missing required field: level\n"
      if [ -n "$level" ] && { [ "$level" -lt 0 ] || [ "$level" -gt 4 ]; } 2>/dev/null; then
        errors="${errors}Invalid level: $level (must be 0-4)\n"
      fi
      ;;

    *)
      # Unknown schema — just validate JSON syntax
      ;;
  esac

  if [ -n "$errors" ]; then
    echo "SCHEMA VALIDATION FAILED ($schema_name):" >&2
    printf '%b' "$errors" >&2
    return 1
  fi
  return 0
}

# --- V11: Tool Policy Cascade Functions ---

# Tool group definitions (inline for performance — no file I/O)
V11_GROUP_READ="Read Grep Glob"
V11_GROUP_WRITE="Write Edit"
V11_GROUP_EXEC="Bash"
V11_GROUP_TASK="TaskCreate TaskUpdate TaskList TaskGet"
V11_GROUP_TEAM="SendMessage TeamCreate"
V11_GROUP_SEARCH="WebSearch WebFetch"
V11_GROUP_FS="Read Write Edit Grep Glob"
V11_GROUP_ALL_READ="Read Grep Glob WebSearch WebFetch"
V11_GROUP_TEST="Bash"
V11_GROUP_DEPLOY="Bash"

# Expand a group name to tool list. Returns space-separated tool names.
# Usage: v11_expand_group "group:read"
v11_expand_group() {
  case "$1" in
    group:read)     echo "$V11_GROUP_READ" ;;
    group:write)    echo "$V11_GROUP_WRITE" ;;
    group:exec)     echo "$V11_GROUP_EXEC" ;;
    group:task)     echo "$V11_GROUP_TASK" ;;
    group:team)     echo "$V11_GROUP_TEAM" ;;
    group:search)   echo "$V11_GROUP_SEARCH" ;;
    group:fs)       echo "$V11_GROUP_FS" ;;
    group:all-read) echo "$V11_GROUP_ALL_READ" ;;
    group:test)     echo "$V11_GROUP_TEST" ;;
    group:deploy)   echo "$V11_GROUP_DEPLOY" ;;
    *)              echo "$1" ;;  # Not a group, return as-is (individual tool)
  esac
}

# Expand a profile name to its included tool list.
# Usage: v11_expand_profile "coding"
v11_expand_profile() {
  case "$1" in
    full)     echo "$V11_GROUP_READ $V11_GROUP_WRITE $V11_GROUP_EXEC $V11_GROUP_TASK $V11_GROUP_TEAM $V11_GROUP_SEARCH" ;;
    coding)   echo "$V11_GROUP_FS $V11_GROUP_EXEC $V11_GROUP_TASK" ;;
    testing)  echo "$V11_GROUP_READ $V11_GROUP_TEST $V11_GROUP_TASK" ;;
    readonly) echo "$V11_GROUP_READ $V11_GROUP_TASK" ;;
    minimal)  echo "$V11_GROUP_TASK" ;;
    *)        echo "" ;;  # Unknown profile
  esac
}

# Check if a tool is in a space-separated list.
# Usage: v11_tool_in_list "Read" "$tool_list"
v11_tool_in_list() {
  local tool="$1" list="$2"
  case " $list " in
    *" $tool "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve tool policy for current agent/role/formation.
# Uses deny-wins semantics: if any layer denies, tool is denied.
#
# Reads .formation-registry.json in current directory (or session dir).
# Requires V11_AGENT_ID to be set.
#
# Usage: v11_resolve_tool_policy TOOL_NAME [REGISTRY_PATH]
# Returns: 0=allowed, 1=denied (with reason on stdout)
# Sets: V11_POLICY_REASON (human-readable explanation)
v11_resolve_tool_policy() {
  local tool_name="$1"
  local registry_path="${2:-.formation-registry.json}"
  V11_POLICY_REASON=""

  # No registry = no policy enforcement
  if [ ! -f "$registry_path" ]; then
    V11_POLICY_REASON="No formation registry — all tools allowed"
    return 0
  fi

  # No agent ID = can't check policy
  if [ -z "${V11_AGENT_ID:-}" ]; then
    V11_POLICY_REASON="No agent ID — policy not enforced"
    return 0
  fi

  local registry
  registry=$(cat "$registry_path" 2>/dev/null)
  [ -z "$registry" ] && return 0

  # Find current agent's role
  local current_role=""
  current_role=$(printf '%s' "$registry" | jq -r --arg aid "$V11_AGENT_ID" '
    .teammates // {} | to_entries[]
    | select(.value.agent_id == $aid)
    | .key
  ' 2>/dev/null)

  [ -z "$current_role" ] && {
    V11_POLICY_REASON="Agent $V11_AGENT_ID not in registry — default allow"
    return 0
  }

  # Layer 1: Formation defaults
  local default_profile default_deny default_allow
  default_profile=$(printf '%s' "$registry" | jq -r '.tool_policies.defaults.profile // empty' 2>/dev/null)
  default_deny=$(printf '%s' "$registry" | jq -r '.tool_policies.defaults.deny // [] | .[]' 2>/dev/null | tr '\n' ' ')
  default_allow=$(printf '%s' "$registry" | jq -r '.tool_policies.defaults.allow // [] | .[]' 2>/dev/null | tr '\n' ' ')

  # Layer 2: Role overrides (from tool_policies.per_role)
  local role_profile role_deny role_allow
  role_profile=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.tool_policies.per_role[$role].profile // empty' 2>/dev/null)
  role_deny=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.tool_policies.per_role[$role].deny // [] | .[]' 2>/dev/null | tr '\n' ' ')
  role_allow=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.tool_policies.per_role[$role].allow // [] | .[]' 2>/dev/null | tr '\n' ' ')

  # Layer 3: Teammate-level overrides (from teammates.ROLE.tool_policies)
  local teammate_profile teammate_deny teammate_allow
  teammate_profile=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.teammates[$role].tool_policies.profile // empty' 2>/dev/null)
  teammate_deny=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.teammates[$role].tool_policies.deny // [] | .[]' 2>/dev/null | tr '\n' ' ')
  teammate_allow=$(printf '%s' "$registry" | jq -r --arg role "$current_role" '.teammates[$role].tool_policies.allow // [] | .[]' 2>/dev/null | tr '\n' ' ')

  # Effective profile: teammate > role > formation default (most specific wins)
  local effective_profile="${teammate_profile:-${role_profile:-$default_profile}}"
  [ -z "$effective_profile" ] && effective_profile="full"

  # Expand profile to allowed tools
  local allowed_tools
  allowed_tools=$(v11_expand_profile "$effective_profile")

  # Add explicit allows from all layers
  for allow_entry in $default_allow $role_allow $teammate_allow; do
    local expanded
    expanded=$(v11_expand_group "$allow_entry")
    allowed_tools="$allowed_tools $expanded"
  done

  # Check if tool is in allowed set
  if ! v11_tool_in_list "$tool_name" "$allowed_tools"; then
    V11_POLICY_REASON="Tool '$tool_name' not in profile '$effective_profile' for role '$current_role'"
    echo "$V11_POLICY_REASON"
    return 1
  fi

  # Deny-wins: check all deny lists from all layers (expand groups)
  local all_denied=""
  for deny_entry in $default_deny $role_deny $teammate_deny; do
    local expanded
    expanded=$(v11_expand_group "$deny_entry")
    all_denied="$all_denied $expanded"
  done

  if v11_tool_in_list "$tool_name" "$all_denied"; then
    V11_POLICY_REASON="Tool '$tool_name' denied for role '$current_role' (deny-wins cascade)"
    echo "$V11_POLICY_REASON"
    return 1
  fi

  V11_POLICY_REASON="Allowed: profile=$effective_profile, role=$current_role"
  return 0
}

# Backward-compatibility aliases (V10 → V11)
v10_parse_input() { v11_parse_input "$@"; }
v10_detect_project() { v11_detect_project "$@"; }
v10_risk_level() { v11_risk_level "$@"; }
v10_check_risk() { v11_check_risk "$@"; }
v10_check_autonomy() { v11_check_autonomy "$@"; }
v10_check_file_ownership() { v11_check_file_ownership "$@"; }
v10_is_metadata_file() { v11_is_metadata_file "$@"; }
v10_resolve_tool_policy() { v11_resolve_tool_policy "$@"; }
