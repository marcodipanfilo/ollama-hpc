#!/usr/bin/env bash
set -euo pipefail

PROMPT='What are VKG mappings. Respond in maximum 3 sentences.'

JSON=$(printf '{"model":"deepseek-r1:8b","stream":false,"messages":[{"role":"user","content":"%s"}]}' "$PROMPT")

# One place to add/remove endpoints
# Format: LABEL|URL
ENDPOINTS=(
  "local|http://localhost:11434/api/chat"
  "obdalin|http://obdalin.inf.unibz.it:11434/api/chat"
  "hpc-cluster|http://localhost:5000/api/chat"
)

LOG_DIR="logs/speedtest"
mkdir -p "$LOG_DIR"

echo "Running unified Ollama-style calls..."
echo

PIDS=()

for ENTRY in "${ENDPOINTS[@]}"; do
  LABEL="${ENTRY%%|*}"
  URL="${ENTRY#*|}"

  OUT="$LOG_DIR/output_${LABEL}.txt"
  TIMEFILE="$LOG_DIR/time_${LABEL}.txt"

  echo "Calling: $LABEL → $URL"

  { time curl -s -H "Content-Type: application/json" -d "$JSON" "$URL" > "$OUT"; } 2> "$TIMEFILE" &
  PIDS+=("$!")
done

for pid in "${PIDS[@]}"; do
  wait "$pid"
done

echo
echo "========================="
echo "TIMES"
echo "========================="
for ENTRY in "${ENDPOINTS[@]}"; do
  LABEL="${ENTRY%%|*}"
  URL="${ENTRY#*|}"
  TIMEFILE="$LOG_DIR/time_${LABEL}.txt"

  echo "$LABEL ($URL):"
  grep '^real' "$TIMEFILE" || cat "$TIMEFILE"
  echo
done

echo "========================="
echo "OUTPUTS"
echo "========================="
for ENTRY in "${ENDPOINTS[@]}"; do
  LABEL="${ENTRY%%|*}"
  URL="${ENTRY#*|}"
  OUT="$LOG_DIR/output_${LABEL}.txt"

  echo "---- $LABEL ($URL) ----"
  cat "$OUT"
  echo
  echo "------------------------"
  echo
done