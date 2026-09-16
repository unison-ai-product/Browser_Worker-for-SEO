#!/bin/bash
# seo-content-worker の検証を一発で回す（CI / Release / /SEO検証 quick が呼ぶ）。全 PASS で exit 0。
#   bash scripts/verify.sh            全項目
#   bash scripts/verify.sh --release  さらにタグ/version の整合（環境変数 TAG=vX.Y.Z を見る）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
export PYTHONIOENCODING=utf-8
FAIL=0
ok()   { echo "PASS: $1"; }
ng()   { echo "FAIL: $1"; FAIL=1; }
step() { if eval "$2" >/tmp/verify.out 2>&1; then ok "$1"; else ng "$1"; sed 's/^/    /' /tmp/verify.out | tail -15; fi; }

# 1. manifests
step "plugin.json is valid and named seo-content-worker" \
  "$PY -c \"import json; d=json.load(open('.claude-plugin/plugin.json', encoding='utf-8')); assert d['name']=='seo-content-worker'\""
step "marketplace.json / hooks.json are valid JSON" \
  "$PY -c \"import json; json.load(open('.claude-plugin/marketplace.json', encoding='utf-8')); json.load(open('hooks/hooks.json', encoding='utf-8'))\""
step "plugin.json and marketplace.json versions match" \
  "$PY -c \"import json; a=json.load(open('.claude-plugin/plugin.json', encoding='utf-8'))['version']; b=json.load(open('.claude-plugin/marketplace.json', encoding='utf-8'))['plugins'][0]['version']; assert a==b, (a,b)\""

# 2. structure
check_skills() { for f in skills/*/SKILL.md; do d=$(basename "$(dirname "$f")"); n=$(grep -m1 '^name:' "$f" | sed 's/name: *//'); [ "$d" = "$n" ] || { echo "$d != $n"; return 1; }; done; }
step "skill names match directories" check_skills
check_agents() { for a in serp-collector article-analyzer unit-drafter diagram-maker fact-checker keyword-gate pre-publish-verifier fix-integrator adversarial-reviewer; do [ -f "agents/$a.md" ] && grep -q "^name: $a\$" "agents/$a.md" || { echo "agent $a"; return 1; }; done; }
step "9 agents exist with matching names" check_agents
check_procs() { for p in seo-start seo-article seo-serps seo-analysis seo-outline seo-write seo-setup seo-verify; do [ -f "procedures/$p.md" ] || { echo "procedure $p"; return 1; }; done; [ "$(ls commands/*.md | wc -l)" -ge 7 ]; }
step "8 procedures and 7 commands exist" check_procs
check_roster() { diff <(grep -o "ROSTER='[^']*'" hooks/scripts/subagent-guard.sh | sed "s/ROSTER='//;s/'//" | tr '|' '\n' | sort) <(ls agents/*.md | xargs -n1 basename | sed 's/\.md$//' | sort); }
step "subagent-guard roster == agents/" check_roster
check_cmds() { for c in commands/*.md; do p=$(grep -o 'procedures/[a-z-]*\.md' "$c" | head -1); [ -n "$p" ] && [ -f "$p" ] || { echo "$c -> $p"; return 1; }; done; }
step "every command points to an existing procedure" check_cmds
check_status() { ! grep -l '未記入' skills/*/SKILL.md; }
step "no skill is left as an empty skeleton (未記入)" check_status

# 3. scripts
step "python scripts compile" "$PY -m py_compile scripts/seo-db.py scripts/wp-draft.py scripts/keyword-gate.py"
step "hooks smoke test" "bash scripts/test-hooks.sh"
step "keyword-gate selftest" "$PY scripts/keyword-gate.py --selftest"
db_smoke() { local t; t=$(mktemp -d); SEO_DB="$t/seo.db" $PY scripts/seo-db.py init >/dev/null && printf '[{"kind":"claim","theme":"t","stance":"neutral","title":"x","meta_description":"ダミー知識","body":"b","dated":"2026-09"}]' > "$t/k.json" && SEO_DB="$t/seo.db" $PY scripts/seo-db.py knowledge add --json "$t/k.json" >/dev/null && SEO_DB="$t/seo.db" $PY scripts/seo-db.py knowledge search --q "ダミー" | grep -q '"id": 1'; local r=$?; rm -rf "$t"; return $r; }
step "sqlite schema + knowledge FTS search" db_smoke
wp_refuse() { local out rc; out=$($PY scripts/wp-draft.py --site https://example.invalid --title t --content README.md --status publish); rc=$?; [ "$rc" -eq 1 ] && echo "$out" | grep -q '許可されていません'; }
step "wp-draft refuses status=publish" wp_refuse

# 4. release consistency（--release のとき）
if [ "${1:-}" = "--release" ]; then
  v=$($PY -c "import json; print(json.load(open('.claude-plugin/plugin.json', encoding='utf-8'))['version'])")
  step "tag ${TAG:-<unset>} == v$v" "[ \"${TAG:-}\" = \"v$v\" ]"
  step "CHANGELOG has a section for $v" "grep -q \"^## \\[$v\\]\" CHANGELOG.md"
fi

[ "$FAIL" = 0 ] && echo "ALL PASS" || echo "SOME FAIL"
exit $FAIL
