#!/usr/bin/env bash
# Build nvim tree-sitter parsers from source, driven by a committed lockfile.
#
# Default (no flag): reads nvim/parsers.conf + nvim/parsers.lock, builds the
# pinned SHA for every grammar. Reproducible; `./install.sh` uses this mode.
#
# --update: fetches each grammar's configured branch head, rebuilds, and
# rewrites nvim/parsers.lock. Review the diff and commit intentionally.
#
# Output: ~/.local/share/nvim/site/parser/<lang>.so (+ .so.sha sidecar, and
# .so.prev backup of the previous successful build for one-step rollback).

set -eu -o pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
REPO_ROOT="$(dirname -- "$SCRIPT_DIR")"
CONF="$REPO_ROOT/nvim/parsers.conf"
LOCK="$REPO_ROOT/nvim/parsers.lock"
CACHE="$HOME/.cache/nvim-parsers"
PARSER_DIR="$HOME/.local/share/nvim/site/parser"

UPDATE=""
case "${1:-}" in
  --update) UPDATE=yes ;;
  "") ;;
  *)
    echo "Usage: $0 [--update]" >&2
    exit 2
    ;;
esac

if [ ! -f "$CONF" ]; then
  echo "ERROR: $CONF not found" >&2
  exit 1
fi

mkdir -p "$CACHE" "$PARSER_DIR"

declare -A LOCKED NEW_LOCKED
if [ -f "$LOCK" ]; then
  while IFS='=' read -r lang sha; do
    case "$lang" in '' | \#*) continue ;; esac
    LOCKED["$lang"]="$sha"
  done <"$LOCK"
fi

built=0 skipped=0 failed=0

build_one() {
  local lang="$1" url="$2" branch="$3" location="$4"
  local repo_dir="$CACHE/$lang"

  local fresh_clone=""
  if [ ! -d "$repo_dir/.git" ]; then
    git clone --quiet "$url" "$repo_dir"
    fresh_clone=yes
  fi

  local target_sha=""
  if [ -n "$UPDATE" ]; then
    # --update always fetches to see new upstream commits
    [ -z "$fresh_clone" ] && git -C "$repo_dir" fetch --quiet origin
    local ref=""
    if [ -n "$branch" ]; then
      if git -C "$repo_dir" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        ref="origin/$branch"
      elif git -C "$repo_dir" rev-parse --verify --quiet "refs/tags/$branch" >/dev/null; then
        ref="refs/tags/$branch"
      else
        echo "ERROR: $lang: branch/tag '$branch' not found in $url" >&2
        failed=$((failed + 1))
        return
      fi
    else
      local default_ref
      default_ref=$(git -C "$repo_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
      if [ -n "$default_ref" ]; then
        ref="$default_ref"
      else
        # Fallback if origin/HEAD isn't set
        for b in main master; do
          if git -C "$repo_dir" rev-parse --verify --quiet "origin/$b" >/dev/null; then
            ref="origin/$b"
            break
          fi
        done
      fi
    fi
    if [ -z "$ref" ]; then
      echo "ERROR: $lang: no default branch found in $url" >&2
      failed=$((failed + 1))
      return
    fi
    target_sha=$(git -C "$repo_dir" rev-parse "$ref")
    NEW_LOCKED["$lang"]="$target_sha"
  else
    target_sha="${LOCKED[$lang]:-}"
    if [ -z "$target_sha" ]; then
      echo "ERROR: $lang: no entry in $LOCK; run with --update first" >&2
      failed=$((failed + 1))
      return
    fi
  fi

  local out="$PARSER_DIR/$lang.so"
  local sha_file="$PARSER_DIR/$lang.so.sha"
  if [ -f "$out" ] && [ -f "$sha_file" ] && [ "$(cat "$sha_file")" = "$target_sha" ]; then
    skipped=$((skipped + 1))
    return
  fi

  # Default mode may need to fetch if the pinned SHA landed after our clone
  # (e.g. teammate bumped the lockfile). Skipped when the SHA is already local.
  if [ -z "$UPDATE" ] && ! git -C "$repo_dir" cat-file -e "$target_sha" 2>/dev/null; then
    git -C "$repo_dir" fetch --quiet origin
  fi

  git -C "$repo_dir" checkout --quiet --force "$target_sha"

  local src="$repo_dir/src"
  [ -n "$location" ] && src="$repo_dir/$location/src"
  if [ ! -f "$src/parser.c" ]; then
    echo "ERROR: $lang: $src/parser.c missing" >&2
    failed=$((failed + 1))
    return
  fi

  local compiler=cc
  local -a sources=("$src/parser.c")
  if [ -f "$src/scanner.cc" ]; then
    compiler=c++
    sources+=("$src/scanner.cc")
  elif [ -f "$src/scanner.cpp" ]; then
    compiler=c++
    sources+=("$src/scanner.cpp")
  elif [ -f "$src/scanner.c" ]; then
    sources+=("$src/scanner.c")
  fi

  # Backup previous build
  [ -f "$out" ] && mv -f "$out" "$out.prev"

  local log="/tmp/nvim-parser-build-$lang.log"
  if "$compiler" -O2 -fPIC -shared -I"$src" -o "$out" "${sources[@]}" 2>"$log"; then
    echo "$target_sha" >"$sha_file"
    rm -f "$log"
    built=$((built + 1))
  else
    echo "ERROR: $lang: compile failed" >&2
    cat "$log" >&2
    # Restore previous .so so nvim isn't left without a parser
    [ -f "$out.prev" ] && mv -f "$out.prev" "$out"
    failed=$((failed + 1))
  fi
}

while IFS='|' read -r lang url branch location; do
  case "$lang" in '' | \#*) continue ;; esac
  build_one "$lang" "$url" "$branch" "$location"
done <"$CONF"

# Queries: nvim ships highlight/fold/indent queries for only ~7 languages.
# For the rest (go, perl, bash, python, ts, ...) we sync nvim-treesitter's
# bundled queries from a pinned commit of the now-archived repo. markdown
# queries are excluded so nvim's built-in (working) ones take precedence.
QUERIES_REPO="https://github.com/nvim-treesitter/nvim-treesitter"
QUERIES_PIN_FILE="$REPO_ROOT/nvim/queries.commit"
QUERIES_DEST="$HOME/.local/share/nvim/site/queries"
QUERIES_CACHE="$CACHE/_queries_src"

sync_queries() {
  [ -f "$QUERIES_PIN_FILE" ] || return 0
  local pin
  pin=$(grep -v '^#' "$QUERIES_PIN_FILE" | tr -d '[:space:]' | head -c 40)
  [ -n "$pin" ] || return 0

  if [ ! -d "$QUERIES_CACHE/.git" ]; then
    git clone --quiet "$QUERIES_REPO" "$QUERIES_CACHE"
  fi
  if ! git -C "$QUERIES_CACHE" cat-file -e "$pin" 2>/dev/null; then
    git -C "$QUERIES_CACHE" fetch --quiet origin
  fi

  local current=""
  [ -f "$QUERIES_DEST/.sha" ] && current=$(cat "$QUERIES_DEST/.sha")
  if [ "$current" = "$pin" ]; then
    echo "Queries: up to date ($pin)"
    return 0
  fi

  git -C "$QUERIES_CACHE" checkout --quiet --force "$pin"
  mkdir -p "$QUERIES_DEST"
  rsync -a --delete \
    --exclude='/markdown/' --exclude='/markdown_inline/' --exclude='.sha' \
    "$QUERIES_CACHE/queries/" "$QUERIES_DEST/"
  echo "$pin" >"$QUERIES_DEST/.sha"
  echo "Queries: synced at $pin"
}

sync_queries

if [ -n "$UPDATE" ]; then
  {
    echo "# nvim tree-sitter parser commit pins (see parsers.conf for sources)."
    echo "# Regenerate with: ./install/nvim-parsers.sh --update"
    for lang in "${!NEW_LOCKED[@]}"; do
      echo "$lang=${NEW_LOCKED[$lang]}"
    done | LC_ALL=C sort
  } >"$LOCK"
  echo ""
  echo "Lockfile updated: ${#NEW_LOCKED[@]} grammars"
fi

echo ""
echo "Parsers: $built built, $skipped skipped, $failed failed"
[ "$failed" -eq 0 ]
