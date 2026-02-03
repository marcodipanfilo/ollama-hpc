#!/bin/bash

PROMPT='What are VKG mappings. Respond in maximum 3 sentences.'

# One JSON body, reused everywhere
JSON=$(printf '{"model":"deepseek-r1:8b","stream":false,"messages":[{"role":"user","content":"%s"}]}' "$PROMPT")

# All three endpoints treated as "Ollama-like"
URLS=(
  "http://localhost:11434/api/chat" # Local Ollama server
  "http://obdalin.inf.unibz.it:11434/api/chat" # Remote obdalin Ollama server
  "http://localhost:5000/api/chat" # Remote Ollama server on unibz HPC cluster
)

echo "Running unified Ollama-style calls..."
echo

# Example: benchmark + capture outputs
i=0
for URL in "${URLS[@]}"; do
  i=$((i+1))
  OUT="output_$i.txt"
  TIME="time_$i.txt"

  echo "Calling: $URL"
  { time curl -s -H "Content-Type: application/json" -d "$JSON" "$URL" > "$OUT"; } 2> "$TIME" &
  PIDS[$i]=$!
done

# Wait for all
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

echo
echo "========================="
echo "TIMES"
echo "========================="
i=0
for URL in "${URLS[@]}"; do
  i=$((i+1))
  echo "$URL:"
  grep real "time_$i.txt"
  echo
done

echo "========================="
echo "OUTPUTS"
echo "========================="
i=0
for URL in "${URLS[@]}"; do
  i=$((i+1))
  echo "---- $URL ----"
  cat "output_$i.txt"
  echo -e "\n------------------------\n"
done