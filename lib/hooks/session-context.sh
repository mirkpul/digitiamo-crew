#!/usr/bin/env bash
# Hook SessionStart (startup, resume, compact): reinserisce nel contesto lo stato
# di lavoro e le lezioni apprese, così l'agente riprende da dove era rimasto.
set -uo pipefail

input=$(cat)
dir=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
dir=${dir:-$PWD}
source=$(jq -r '.source // "startup"' <<<"$input" 2>/dev/null)

read_or() { [[ -s "$1" ]] && cat "$1" || echo "$2"; }

ctx="# Contesto ripristinato ($source, $(date '+%F %H:%M'))

## Lavoro in corso (state/now.md)
$(read_or "$dir/state/now.md" "(nessun lavoro in corso)")

## Lezioni apprese (state/lessons.md)
$(read_or "$dir/state/lessons.md" "(nessuna lezione ancora)")

## Routine (routines.yaml)
$(read_or "$dir/routines.yaml" "(nessuna routine)")"

jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
