#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="aleo-leo"
GLOBAL=false
FORCE=false
YES=false

usage() {
  echo "Usage: $0 [--global|-g] [--force|-f] [--yes|-y]"
  echo ""
  echo "Install aleo-skills for Claude Code."
  echo ""
  echo "  --global, -g    Install to ~/.claude/skills/ (all projects)"
  echo "  --local         Install to ./.claude/skills/ (current project, default)"
  echo "  --force, -f     Overwrite existing installation"
  echo "  --yes, -y       Skip confirmation prompt"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --global|-g) GLOBAL=true; shift ;;
    --local)     GLOBAL=false; shift ;;
    --force|-f)  FORCE=true; shift ;;
    --yes|-y)    YES=true; shift ;;
    --help|-h)   usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [ "$GLOBAL" = true ]; then
  SKILLS_DIR="$HOME/.claude/skills"
else
  SKILLS_DIR="$(pwd)/.claude/skills"
fi

DEST="$SKILLS_DIR/$SKILL_NAME"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Aleo Skills Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Skill:    $SKILL_NAME"
echo "Target:   $DEST"
if [ "$GLOBAL" = true ]; then
  echo "Scope:    Global (all projects)"
else
  echo "Scope:    Local (current directory)"
fi
echo ""

if [ -d "$DEST" ] && [ "$FORCE" != true ]; then
  echo "ERROR: $DEST already exists. Use --force to overwrite."
  exit 1
fi

if [ "$YES" != true ]; then
  read -p "Proceed? (y/n): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

[ -d "$DEST" ] && rm -rf "$DEST"
mkdir -p "$DEST"

cp "$SCRIPT_DIR/SKILL.md" "$DEST/SKILL.md"
if [ -d "$SCRIPT_DIR/references" ]; then
  cp -r "$SCRIPT_DIR/references" "$DEST/references"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installed $SKILL_NAME to $DEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
