#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname "$0")/../.." && pwd)
source=$(nix eval --raw --impure --expr "let f = builtins.getFlake \"path:$repo\"; in f.inputs.superpowers.outPath")
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

mkdir -p "$workdir/skills/subagent-driven-development/scripts"
cp "$source/skills/subagent-driven-development/scripts/task-brief" "$workdir/skills/subagent-driven-development/scripts/"
git -C "$workdir" apply "$repo/patches/superpowers-task-brief-identifiers.patch"

check() {
  local heading=$1
  local id=$2
  local plan="$workdir/$id-plan.md"
  local out="$workdir/$id-out.md"
  local expected

  printf '%s\nbody for %s\n' "$heading" "$id" > "$plan"
  "$workdir/skills/subagent-driven-development/scripts/task-brief" "$plan" "$id" "$out" >/dev/null
  printf -v expected '%s\nbody for %s' "$heading" "$id"
  test "$(<"$out")" = "$expected"
}

check "# Task 1. Description" 1
check "# Task 1: Description" 1
check "# Task T1: Description" T1
