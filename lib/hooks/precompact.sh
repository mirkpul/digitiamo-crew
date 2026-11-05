#!/usr/bin/env bash
# Hook PreCompact: prima che Claude compatti la conversazione, salva nel diario
# del giorno gli ultimi scambi e lo stato corrente, così nulla di importante va perso.
set -uo pipefail

input=$(cat)
dir=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
dir=${dir:-$PWD}
transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
trigger=$(jq -r '.trigger // "?"' <<<"$input" 2>/dev/null)

journal_dir="$dir/state/journal"
mkdir -p "$journal_dir"
out="$journal_dir/$(date +%F).md"

{
  echo
  echo "## $(date +%H:%M) — compattazione ($trigger)"
  echo
  echo "### Ultimi scambi prima della compattazione"
  if [[ -n "$transcript" && -f "$transcript" ]]; then
    tail -n 600 "$transcript" | jq -r '
      select(.type == "user" or .type == "assistant")
      | (.message.content
         | if type == "string" then .
           else (map(select(.type == "text") | .text) | join(" ")) end) as $t
      | select(($t | length) > 0)
      | "- **\(.type)**: \($t | gsub("\\s+"; " ") | .[0:400])"
    ' 2>/dev/null | tail -n 30
  else
    echo "(trascrizione non disponibile)"
  fi
  echo
  echo "### state/now.md in quel momento"
  cat "$dir/state/now.md" 2>/dev/null || echo "(vuoto)"
} >> "$out"

exit 0
