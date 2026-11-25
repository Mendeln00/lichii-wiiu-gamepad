#!/usr/bin/env bash
# SessionStart hook for Claude Code: bring the checkout up to date and print a
# short status. Claude Code adds stdout to the new session's context.
# Best effort only: no step may block or fail the session start.

export GIT_TERMINAL_PROMPT=0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

main=main
echo "## Stand beim Sitzungsstart"
echo

if ! git fetch --prune --quiet origin 2>/dev/null; then
  echo "- \`git fetch\` fehlgeschlagen (offline?). Der Stand unten kann veraltet sein."
fi

branch=$(git symbolic-ref --short -q HEAD)
dirty=$(git status --porcelain)

# A branch whose upstream is gone was merged and deleted on GitHub.
# Leave it for main when nothing is uncommitted; the local branch stays.
if [ -n "$branch" ] && [ "$branch" != "$main" ] && [ -z "$dirty" ]; then
  track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$branch")
  if [ "$track" = "[gone]" ] && git switch --quiet "$main" 2>/dev/null; then
    echo "- Branch \`$branch\` ist auf GitHub gelöscht (PR gemergt). Auf \`$main\` gewechselt."
    branch=$main
  fi
fi

if [ "$branch" = "$main" ]; then
  before=$(git rev-parse --short HEAD)
  if [ -n "$dirty" ]; then
    behind=$(git rev-list --count "HEAD..origin/$main" 2>/dev/null)
    echo "- Auf \`$main\` mit lokalen Änderungen, nicht aktualisiert (${behind:-?} Commits hinter origin)."
  elif git merge --ff-only --quiet "origin/$main" 2>/dev/null; then
    after=$(git rev-parse --short HEAD)
    if [ "$before" = "$after" ]; then
      echo "- Auf \`$main\`, aktuell mit origin ($after)."
    else
      echo "- \`$main\` per Fast-Forward aktualisiert: $before → $after."
    fi
  else
    echo "- \`$main\` lässt sich nicht per Fast-Forward aktualisieren. Lokale Commits prüfen."
  fi
elif [ -n "$branch" ]; then
  # Keep the local main current without touching the checked-out branch.
  git fetch --quiet origin "$main:$main" 2>/dev/null
  read -r behind ahead <<< "$(git rev-list --left-right --count "origin/$main...HEAD" 2>/dev/null)"
  echo "- Auf Branch \`$branch\` (gegenüber origin/$main: ${behind:-?} hinter, ${ahead:-?} voraus)."
  echo "  Gehört der Branch zu einer abgeschlossenen Aufgabe, erst klären, dann auf \`$main\` wechseln."
else
  echo "- Kein Branch ausgecheckt (detached HEAD bei $(git rev-parse --short HEAD))."
fi

if [ -n "$dirty" ]; then
  echo "- Nicht committete Änderungen:"
  printf '%s\n' "$dirty" | head -n 10 | sed 's/^/    /'
fi

stashes=$(git stash list | wc -l | tr -d ' ')
[ "$stashes" != "0" ] && echo "- $stashes Stash-Einträge vorhanden (\`git stash list\`)."

gone=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" { print $1 }' | tr '\n' ' ')
[ -n "$gone" ] && echo "- Lokale Branches ohne Gegenstück auf GitHub: $gone"

echo
echo "Letzte Commits auf origin/$main:"
git log --oneline -5 "origin/$main" 2>/dev/null | sed 's/^/    /'

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo
  echo "(gh fehlt oder ist nicht angemeldet: PRs und Tickets nicht abgefragt.)"
  exit 0
fi

echo
echo "Offene PRs:"
prs=$(gh pr list --state open --limit 20 --json number,title,headRefName,isDraft \
  --jq '.[] | "    #\(.number) \(.title) (\(.headRefName))\(if .isDraft then " [Entwurf]" else "" end)"' 2>/dev/null)
echo "${prs:-    keine}"

# Frontier: open tickets without open blockers. Plan B rests (ADR 0005).
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100) {
      nodes {
        number title
        milestone { title }
        labels(first: 20) { nodes { name } }
        blockedBy(first: 20) { nodes { state } }
      }
    }
  }
}' --jq '
  [.data.repository.issues.nodes[]
    | {n: .number, t: .title, m: (.milestone.title // "ohne Milestone"),
       l: [.labels.nodes[].name],
       blocked: ([.blockedBy.nodes[] | select(.state == "OPEN")] | length > 0)}] as $all
  | ($all | map(select(.m | startswith("Plan B") | not))) as $active
  | def show($label):
      ($active | map(select((.blocked | not) and (.l | index($label)))))
      | if length == 0 then "    keine"
        else .[] | "    #\(.n) [\(.m | split(" ")[0])] \(.t)" end;
    "", "Frei für Agenten (ready-for-agent, keine offenen Blocker):", show("ready-for-agent"),
    "", "Frei für Menschen (ready-for-human, keine offenen Blocker):", show("ready-for-human"),
    "", "Zu sichten (needs-triage): \($active | map(select(.l | index("needs-triage"))) | length). Plan B ruht: \(($all | length) - ($active | length)) Tickets nicht gelistet."
' 2>/dev/null || echo "    (Tickets konnten nicht abgefragt werden.)"

exit 0
