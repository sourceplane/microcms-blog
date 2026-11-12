#!/usr/bin/env bash
# TIER 2 — the blog a bootstrap produces builds, deploys (dry) and serves,
# first with NO microCMS service behind it, then connected to one.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges), the
#      landing's own checks — install with the lockfile the product ships,
#      render fixtures and check the committed config is the render,
#      typecheck, lint, test, build. The bootstrap's landings are checked in
#      the box with `orun validate` and `orun plan` alone (`checks: local`;
#      their PR's CI on an `orun/BASE-…` branch is `plan` alone), and a
#      product's later pull requests build and dry-deploy it through ci.yml's
#      lanes, so THIS is where a product those steps refuse is caught: before
#      the tag, not after a build has merged it. Then the same at the 02-docs
#      landing, the finished blog;
#   2. the stage lane's own steps, read out of `orun plan` in the product for
#      a pull request (the verify profile: the deploy profile has no dry run)
#      — EVERY `run:` step of the job, in order, exactly as planned: the
#      install, `verify-app-structure` (the committed `package.json` and
#      `wrangler.jsonc`, checked BEFORE any build), `build-app` (TypeGen,
#      `next build` on Turbopack, the OpenNext bundle, then
#      tooling/wire/worker-secrets.mjs), `verify-build-output` and
#      `deploy-dry-run` (`wrangler deploy --dry-run --name
#      <reponame>-web-stage`). They run IN THE TREE THE RUNNER STAGES for the
#      job (testing/lib/stage-job.py), with no build output in it and the
#      dependency layout the pinned composition produces. The job's microCMS
#      refs are optional; here the lane is given BOTH, as an owner who has
#      connected a service gives them, so this can prove the build never
#      sees them (`env -u`: neither value is anywhere in .next or
#      .open-next) and that a verify lane, which holds no Cloudflare
#      credential, pushes nothing to a Worker;
#   3. serve the built Worker with `wrangler dev`, as a product nobody has
#      connected yet is served, and run the component's OWN `smokeCommand`
#      against it, verbatim and then inside the deploy profile's planned
#      `smoke` step (its retry loop and all — only its workers.dev URL
#      swapped for the local one); then read every route the blog promises:
#      the home page under the "not connected" notice with its three sample
#      posts, each post with its writer and highlighted code, a tag, a
#      search, a second page, the blog's name in the title, the logo and the
#      footer, the Open Graph image on the stage origin, the template's cache
#      headers (a draft never cached), the 404s, and the static assets;
#   4. serve the SAME build connected: the e2e's own entry
#      (testing/lib/e2e-worker.mjs) wraps it so the requests the template's
#      SDK makes to <service>.microcms.io reach a local stand-in for
#      microCMS's content API (testing/lib/fake-microcms.py), and the Worker
#      is given the service and its key as the deploy gives them. The posts,
#      the second page, an article with its writer and highlighted code, a
#      draft read by its draft key and never cached, a tag, a search and a
#      missing article are read from it, the smoke passes on it, and the
#      stand-in saw the key on every request, for the service's own host.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev — nor
# microCMS's: a blog reading a real service needs one. That is a bootstrap
# against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, setsid, and the
# network for `pnpm install` (or a warm store). Several minutes: three
# installs and three Next.js builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl setsid; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
standin_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
stop_group() { # PGID
  [ -n "$1" ] || return 0
  kill -TERM -- "-$1" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$1" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$1" 2>/dev/null || true
}
cleanup() {
  stop_group "$dev_pid"
  stop_group "$standin_pid"
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1
# NO microCMS SERVICE and NO Cloudflare credential, whatever the caller's shell
# holds: the lane below is given the service exactly as the e2e sets it, and a
# verify lane never holds a Cloudflare token.
unset MICROCMS_SERVICE_DOMAIN MICROCMS_API_KEY E2E_MICROCMS_ORIGIN CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the product builds and dry-deploys the blog
# through ci.yml's lanes; the lint and the tests run here, and by hand before
# a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
echo "   2 phases placed and landed on orun's Initial commit"

# ── 1. each landing's own checks ───────────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# Its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

echo "── 02-docs's landing (the finished blog): the same checks"
checks "$tree" "$scratch/checks-blog.log"
grep -q '(Turbopack)' "$scratch/checks-blog.log" \
  || { echo "FAIL: the landing's build did not run on Turbopack" >&2; exit 1; }

# ── 2. the stage lane, as a pull request plans it ──────────────────────────
echo "── the stage lane: every run step the PR plan gives web@stage, in a staged job tree"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-pr.json") > "$scratch/plan-pr.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan-pr.log" >&2; exit 1; }
python3 - "$scratch/plan-pr.json" "$scratch/steps" "$tree" "$values" <<'PY'
import json, pathlib, sys
import yaml
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
tree, values = pathlib.Path(sys.argv[3]), json.load(open(sys.argv[4]))
repo, ws = values["reponame"], values["orunWorkspace"]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
params = yaml.safe_load((tree / "apps/web/component.yaml").read_text())["spec"]["parameters"]
order, uses = [], []
for s in job["steps"]:
    if "use" in s:
        uses.append(f"{s['id']}\t{s['use']}\t{json.dumps(s.get('with') or {})}")
        continue
    order.append(s["id"])
    (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    (out / f"{s['id']}.wd").write_text(s.get("working-directory") or ".")
    if s.get("scope"):
        (out / f"{s['id']}.scope").write_text(s["scope"])
(out / "order").write_text("\n".join(order) + "\n")
(out / "uses").write_text("\n".join(uses) + "\n")
(out / "path").write_text(job.get("path") or "apps/web")
(out / "profile").write_text(job["profile"])
(out / "node").write_text(params["nodeVersion"])
(out / "pnpm").write_text(params["pnpmVersion"])
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
# What the platform resolves into the job before its first step. The
# microCMS service's refs are OPTIONAL: on a product nobody has connected,
# nothing is stored under them, so nothing is exported; on one that has, both
# are — which is what this lane replays.
refs = {r["asEnv"]: r for r in job.get("secretRefs") or []}
for key in ("MICROCMS_SERVICE_DOMAIN", "MICROCMS_API_KEY"):
    r = refs.get(key)
    if not r or r.get("optional") is not True or f"/{repo}/stage/" not in r.get("ref", ""):
        sys.exit(f"FAIL: the stage lane resolves {key} as {r} — want an optional ref to the product's stage secret")
required = sorted(k for k, r in refs.items() if not r.get("optional"))
if required:
    sys.exit(f"FAIL: the verify lane requires secrets {required}; a pull request's lane needs none")
PY
order="$(tr '\n' ' ' < "$scratch/steps/order")"
echo "   $(cat "$scratch/steps/profile"): $order"
for need in install-workspace-dependencies verify-app-structure build-app verify-build-output deploy-dry-run; do
  grep -qx "$need" "$scratch/steps/order" || { echo "FAIL: the stage lane plans no $need step" >&2; exit 1; }
done
[ "$(grep -n -x verify-app-structure "$scratch/steps/order" | cut -d: -f1)" -lt "$(grep -n -x build-app "$scratch/steps/order" | cut -d: -f1)" ] \
  || { echo "FAIL: the structure check is planned after the build" >&2; exit 1; }
# The `use:` steps set up the runner's toolchain; here it is this machine's,
# so it must be the one the component asks for.
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" = "$(cat "$scratch/steps/node")" ] || { echo "FAIL: node $node_major here, the lane sets up $(cat "$scratch/steps/node")" >&2; exit 1; }
[ "$(pnpm --version)" = "$(cat "$scratch/steps/pnpm")" ] || { echo "FAIL: pnpm $(pnpm --version) here, the lane sets up $(cat "$scratch/steps/pnpm")" >&2; exit 1; }
echo "   setup-node $node_major and setup-pnpm $(pnpm --version) stand in for the lane's \`use:\` steps"
echo "   the microCMS service's refs are optional: the lane runs with both set, as a connected owner's does"

# The job's private tree, staged as orun stages it, from a source checkout
# with no build output (a CI checkout has none, so step 1's is removed rather
# than copied in) and the dependencies the pinned composition says: a
# lane-scoped install ran once in the source tree (step 1 ran the same
# command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.next" "$tree/apps/web/.open-next" "$tree/apps/web/.wrangler" "$tree/tests/web/coverage"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
install_scope="$(cat "$scratch/steps/install-workspace-dependencies.scope" 2>/dev/null || echo job)"
if [ "$install_scope" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  [ ! -e "$work/node_modules" ] || { echo "FAIL: the staged tree carries node_modules it should install" >&2; exit 1; }
fi
for built in apps/web/.next apps/web/.open-next apps/web/.wrangler; do
  [ ! -e "$work/$built" ] || { echo "FAIL: the staged tree carries build output ($built)" >&2; exit 1; }
done
echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: $install_scope; no build output"

# The service the platform would resolve for a connected owner: a key no
# file in the tree spells, so a match in the build output can only be a leak.
build_key="e2e-build-key-$(python3 -c 'import secrets;print(secrets.token_hex(12))')"
export MICROCMS_SERVICE_DOMAIN="e2e-build-service" MICROCMS_API_KEY="$build_key"
while IFS= read -r step; do
  [ -n "$step" ] || continue
  if [ "$step" = install-workspace-dependencies ] && [ "$install_scope" = lane ]; then
    echo "   · $step (lane-scoped: ran once in the source tree)"; continue
  fi
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/$step.wd")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the stage lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done < "$scratch/steps/order"
unset MICROCMS_SERVICE_DOMAIN MICROCMS_API_KEY
[ "$install_scope" = lane ] || { [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ]; } \
  || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
# The build this blog is verified with: Turbopack (a webpack build would get
# past an out-of-tree symlink and is not the build that deploys).
grep -q '(Turbopack)' "$scratch/build-app.log" \
  || { echo "FAIL: the staged build did not run on Turbopack" >&2; grep -m3 'Next.js' "$scratch/build-app.log" >&2; exit 1; }
grep -q -- "--name \"\${EFFECTIVE_WORKER_NAME}\"" "$scratch/steps/deploy-dry-run.sh" && grep -q "$repo-web-stage" "$scratch/steps/deploy-dry-run.sh" \
  || { echo "FAIL: the dry run does not name the Worker $repo-web-stage" >&2; exit 1; }
grep -q 'Total Upload' "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run bundled nothing" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the staged build ran on Turbopack; the dry run bundled $repo-web-stage ($(grep -m1 -o 'Total Upload: .*' "$scratch/deploy-dry-run.log"))"
if grep -rlF -e "$build_key" -e "e2e-build-service" "$work/apps/web/.open-next" "$work/apps/web/.next" > "$scratch/leaked.txt" 2>/dev/null; then
  echo "FAIL: the microCMS service or its key is in the build output:" >&2; head -5 "$scratch/leaked.txt" >&2; exit 1
fi
grep -q "worker-secrets: no Cloudflare credential in this job (a verify lane) — MICROCMS_SERVICE_DOMAIN, MICROCMS_API_KEY reach $repo-web-stage from the deploy lane" "$scratch/build-app.log" \
  || { echo "FAIL: build-app did not hand the microCMS secrets to worker-secrets.mjs (or pushed them from a verify lane)" >&2; grep -m3 'worker-secrets' "$scratch/build-app.log" >&2; exit 1; }
echo "   the build never saw the service or its key; worker-secrets.mjs named both and pushed nothing from a verify lane"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the staged Worker, no microCMS service"
port="$(free_port)"; iport="$(free_port)"
# setsid without its own fork: the subshell is not a group leader, so the
# pid recorded IS the new process group's.
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --name "$repo-web-stage" \
   --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) \
   > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 120); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
echo "   ▸ the component's own smokeCommand, verbatim, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the blog" >&2; exit 1; }
if DEPLOYED_URL="$url/no-such-blog" bash -c "$smoke" 2>/dev/null; then
  echo "FAIL: the smoke passed against a path that is not the blog — it checks nothing" >&2; exit 1
fi
echo "   ▸ …and it refuses what is not the blog"

(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-push.json") > "$scratch/plan-push.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-push.log" >&2; exit 1; }
python3 - "$scratch/plan-push.json" "$scratch/smoke-step.sh" "https://$repo-web-stage.$sub.workers.dev" <<'PY'
import json, sys
plan, out, origin = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
assert job["profile"].endswith(".deploy"), job["profile"]
run = next(s for s in job["steps"] if s["id"] == "smoke")["run"]
# The one thing offline cannot reach is workers.dev: the step derives its URL
# from the Worker's name and the account's subdomain, so that line — and only
# that line — is pointed at the local Worker, after checking it is this blog's.
line = 'export DEPLOYED_URL="https://${EFFECTIVE_WORKER_NAME}.${WORKERS_DEV_SUBDOMAIN}.workers.dev"'
if line not in run or 'EFFECTIVE_WORKER_NAME="' + origin.split("//")[1].split(".")[0] + '"' not in run:
    sys.exit(f"FAIL: the planned smoke step does not derive {origin}:\n{run}")
open(out, "w").write(run.replace(line, 'export DEPLOYED_URL="${E2E_LOCAL_URL}"'))
PY
echo "   ▸ the deploy profile's planned smoke step (its retry loop around the same command), on the local Worker"
(E2E_LOCAL_URL="$url" bash "$scratch/smoke-step.sh") > "$scratch/smoke-step.log" 2>&1 \
  || { echo "FAIL: the planned smoke step refused the blog" >&2; tail -20 "$scratch/smoke-step.log" >&2; exit 1; }

echo "   ▸ every route the blog promises, unconnected"
python3 - "$url" "$values" "https://$repo-web-stage.$sub.workers.dev" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values, origin = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
name = values["productname"]
problems = []
def bad(m): problems.append(m)
def get(path, headers=None):
    req = urllib.request.Request(base + path, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
# React separates adjacent text nodes with <!-- -->; compare the text.
def page_of(body): return body.decode().replace("<!-- -->", "")
def text(fragment): return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None
def h1(page):
    m = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
    return text(m.group(1)) if m else None
# The posts a page LISTS: the notice's own link to the connect post is not one.
def posts(page):
    listed = re.sub(r'<aside[^>]*data-microcms-notice.*?</aside>', "", page, flags=re.S)
    return set(re.findall(r'href="/blogs/([^"?#]+)"', listed))
def cache(h): return h.get("CDN-Cache-Control")
NOTICE = 'data-microcms-notice="unconnected"'
POSTS = {"connect-microcms": "Connect your microCMS service",
         "rendered-on-workers": "Rendered on Cloudflare Workers",
         "drafts-tags-and-search": "Drafts, tags and search"}
PUBLIC = "public, s-maxage=60, stale-while-revalidate=300"
NOCACHE = "no-store, must-revalidate"

# The home page: the blog's own name, the notice, every sample post and tag.
s, h, body = get("/")
page = page_of(body)
if s != 200 or not (h.get("content-type") or "").startswith("text/html"):
    bad(f"/ answered {s} {h.get('content-type')}")
if title(page) != name:
    bad(f"the home page's <title> is {title(page)!r}, not {name!r}")
logo = re.search(r"<img[^>]*logo\.svg[^>]*>", page)
alt = logo and re.search(r'alt="([^"]*)"', logo.group(0))
if not alt or html.unescape(alt.group(1)) != name:
    bad(f"the logo's alt text is {alt and html.unescape(alt.group(1))!r}, not {name!r}")
if f"© {name}. All Rights Reserved 2023" not in html.unescape(page):
    bad("the footer does not credit the blog by its name")
if "Simple Blog" in html.unescape(page) and "Simple Blog" not in name:
    bad("the home page still carries the template's name")
if NOTICE not in page or 'href="/blogs/connect-microcms"' not in page:
    bad("the home page does not say the blog is not connected, or where to connect it")
if posts(page) != set(POSTS):
    bad(f"the home page links the posts {sorted(posts(page))}, not the samples {sorted(POSTS)}")
tags = set(re.findall(r'href="/tags/([^"]+)"', page))
if not {"getting-started", "cloudflare"} <= tags:
    bad(f"the home page's tags are {sorted(tags)}")
if cache(h) != PUBLIC:
    bad(f"/ answers CDN-Cache-Control {cache(h)!r}, not the template's {PUBLIC!r}")
og = re.search(r'<meta property="og:image" content="([^"]+)"', page)
if not og or og.group(1) != f"{origin}/ogp.png":
    bad(f"the Open Graph image is {og and og.group(1)!r}, not {origin}/ogp.png (the stage origin)")

# Each sample post, with its writer, under the notice.
for slug, post_title in POSTS.items():
    s, h, body = get(f"/blogs/{slug}")
    p = page_of(body)
    if s != 200:
        bad(f"/blogs/{slug} answered {s}")
        continue
    if h1(p) != post_title:
        bad(f"/blogs/{slug}'s heading is {h1(p)!r}, not {post_title!r}")
    if title(p) != f"{post_title} | {name}":
        bad(f"/blogs/{slug}'s <title> is {title(p)!r}")
    if NOTICE not in p or "Sample Writer" not in p or 'src="/sample/writer.svg"' not in p:
        bad(f"/blogs/{slug} lacks the notice or its writer")
    if cache(h) != PUBLIC:
        bad(f"/blogs/{slug} answers CDN-Cache-Control {cache(h)!r}")
s, _, body = get("/blogs/rendered-on-workers")
if 'class="hljs-keyword"' not in body.decode():
    bad("the sample's code block is not highlighted")
s, _, body = get("/blogs/connect-microcms")
connect = text(body.decode())  # the code block is highlighted: compare its text
for words in ("MICROCMS_SERVICE_DOMAIN", "MICROCMS_API_KEY", "microcms-template.json", "orun secrets set"):
    if words not in connect:
        bad(f"the connect post does not mention {words}")
# A draft (microCMS's preview, ?dk=) is never cached — the rule the
# template's proxy.ts set, in next.config.js here.
s, h, _ = get("/blogs/connect-microcms?dk=e2e-draft")
if s != 200 or cache(h) != NOCACHE:
    bad(f"/blogs/…?dk= answered {s} with CDN-Cache-Control {cache(h)!r}, want {NOCACHE!r}")

# A tag, a search, a second page.
s, _, body = get("/tags/getting-started")
p = page_of(body)
if s != 200 or posts(p) != {"connect-microcms", "drafts-tags-and-search"} or "#getting-started" not in p:
    bad(f"/tags/getting-started answered {s} with {sorted(posts(p))}")
if title(p) != f"getting-started | {name}":
    bad(f"/tags/getting-started's <title> is {title(p)!r}")
s, _, body = get("/search?q=highlight")
if s != 200 or posts(page_of(body)) != {"rendered-on-workers"}:
    bad(f"/search?q=highlight answered {s} with {sorted(posts(page_of(body)))}")
s, _, body = get("/p/2")
if s != 200 or "Article does not exist." not in body.decode():
    bad(f"/p/2 answered {s}, not the template's empty page")

for path in ("/blogs/no-such-post", "/tags/no-such-tag", "/no-such-page"):
    s, _, body = get(path)
    if s != 404 or "Page Not Found" not in body.decode():
        bad(f"{path} answered {s}, want the template's 404 page")

# Static assets, served by the Worker's ASSETS binding.
for path, kind in (("/logo.svg", "image/svg"), ("/no-image.png", "image/png"), ("/ogp.png", "image/png"),
                   ("/sample/writer.svg", "image/svg"), ("/favicon.ico", "image/")):
    s, h, _ = get(path)
    if s != 200 or not (h.get("content-type") or "").startswith(kind):
        bad(f"{path} answered {s} {h.get('content-type')}")
chunk = re.search(r'src="(/_next/static/[^"]+\.js)"', page)
if not chunk:
    bad("the home page loads no script from /_next/static")
else:
    s, h, _ = get(chunk.group(1))
    if s != 200 or "javascript" not in (h.get("content-type") or ""):
        bad(f"{chunk.group(1)} answered {s} {h.get('content-type')}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print("   /, the three sample posts with their writer and highlighting, a draft never cached, a tag, a search,")
print(f"   page 2, three 404s, the Open Graph origin and the static assets — named {name!r}, unconnected and saying so")
PY

# ── 4. the same build, connected ───────────────────────────────────────────
echo "── the same build, connected: testing/lib/e2e-worker.mjs → a local microCMS stand-in"
stop_group "$dev_pid"; dev_pid=""
key="e2e-key-$(python3 -c 'import secrets;print(secrets.token_hex(8))')"
sport="$(free_port)"
(exec setsid python3 "$here/lib/fake-microcms.py" "$sport" "$key") > "$scratch/standin.log" 2>&1 < /dev/null &
standin_pid=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$sport/" && break; sleep 0.2; done
cp "$here/lib/e2e-worker.mjs" "$work/apps/web/e2e-worker.mjs"
sed 's#"main": ".open-next/worker.js"#"main": "e2e-worker.mjs"#' "$work/apps/web/wrangler.jsonc" > "$work/apps/web/wrangler.e2e.jsonc"
grep -q '"main": "e2e-worker.mjs"' "$work/apps/web/wrangler.e2e.jsonc" \
  || { echo "FAIL: could not point a copy of wrangler.jsonc at the e2e's entry" >&2; exit 1; }
port="$(free_port)"; iport="$(free_port)"
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.e2e.jsonc --name "$repo-web-stage" \
   --var "MICROCMS_SERVICE_DOMAIN:e2e-blog" --var "MICROCMS_API_KEY:$key" --var "E2E_MICROCMS_ORIGIN:http://127.0.0.1:$sport" \
   --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) \
   > "$scratch/dev-connected.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 120); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev (connected) exited" >&2; tail -30 "$scratch/dev-connected.log" >&2; exit 1; }
  sleep 1
done
echo "   ▸ the component's own smokeCommand, on the connected Worker"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the connected blog" >&2; tail -20 "$scratch/standin.log" >&2; exit 1; }

echo "   ▸ every route, read from the stand-in"
python3 - "$url" "$values" "$scratch/standin.log" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values, log = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
name = values["productname"]
problems = []
def bad(m): problems.append(m)
def get(path):
    try:
        with urllib.request.urlopen(base + path, timeout=60) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
def page_of(body): return body.decode().replace("<!-- -->", "")
def text(fragment): return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None
def h1(page):
    m = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
    return text(m.group(1)) if m else None
def posts(page): return set(re.findall(r'href="/blogs/([^"?#]+)"', page))
post = lambda i: f"post-{i:02d}"

s, h, body = get("/")
page = page_of(body)
if s != 200 or title(page) != name:
    bad(f"/ answered {s} titled {title(page)!r}")
if 'data-microcms-notice' in page:
    bad("the connected blog still says it is not connected")
if posts(page) != {post(i) for i in range(3, 13)}:
    bad(f"the home page lists {sorted(posts(page))}, not the service's ten newest posts")
if 'href="/p/2"' not in page or not {"tag-edge", "tag-cms"} <= set(re.findall(r'href="/tags/([^"]+)"', page)):
    bad("the home page has no second page, or not the service's tags")
s, _, body = get("/p/2")
if s != 200 or posts(page_of(body)) != {post(1), post(2)}:
    bad(f"/p/2 answered {s} with {sorted(posts(page_of(body)))}")

s, h, body = get("/blogs/post-03")
p = page_of(body)
if s != 200 or h1(p) != "Connected post 03" or title(p) != f"Connected post 03 | {name}":
    bad(f"/blogs/post-03 answered {s}: {h1(p)!r} / {title(p)!r}")
if "Stand-in Writer" not in p or "https://images.microcms-assets.io/assets/e2e/writer.png?fm=webp&amp;fit=crop&amp;w=48&amp;h=48" not in p:
    bad("/blogs/post-03 does not show its writer from the service's image API")
if "https://images.microcms-assets.io/assets/e2e/post-03.png?fm=webp" not in p:
    bad("/blogs/post-03 does not show its thumbnail")
if 'class="hljs-keyword">def<' not in p or "Served by the stand-in &amp; rendered on Workers." not in p:
    bad("/blogs/post-03's rich text is not the service's, highlighted")
if h.get("CDN-Cache-Control") != "public, s-maxage=60, stale-while-revalidate=300":
    bad(f"/blogs/post-03 answers CDN-Cache-Control {h.get('CDN-Cache-Control')!r}")
s, h, body = get("/blogs/post-05?dk=e2e-draft")
if s != 200 or h1(page_of(body)) != "Draft of post 05, unpublished" or h.get("CDN-Cache-Control") != "no-store, must-revalidate":
    bad(f"the draft answered {s}: {h1(page_of(body))!r}, CDN-Cache-Control {h.get('CDN-Cache-Control')!r}")
s, _, body = get("/blogs/post-05")
if h1(page_of(body)) != "Connected post 05":
    bad("without its draft key, post-05 is not the published post")

s, _, body = get("/tags/tag-edge")
p = page_of(body)
if s != 200 or posts(p) != {post(i) for i in (2, 4, 6, 8, 10, 12)} or title(p) != f"edge | {name}":
    bad(f"/tags/tag-edge answered {s} with {sorted(posts(p))}, titled {title(p)!r}")
s, _, body = get("/search?q=post%2007")
if s != 200 or posts(page_of(body)) != {post(7)}:
    bad(f"/search?q=post 07 answered {s} with {sorted(posts(page_of(body)))}")
for path in ("/blogs/no-such-post", "/tags/no-such-tag"):
    s, _, _ = get(path)
    if s != 404:
        bad(f"{path} answered {s}, want 404 (the service said it has no such content)")

# What the Worker asked (the e2e's own readiness probe of the stand-in, GET /, is not).
seen = [r for r in (json.loads(l) for l in open(log) if l.startswith("{")) if r["path"].startswith("/api/")]
if not seen:
    bad("the stand-in saw no request: the Worker did not read microCMS")
if any(r["host"] != "e2e-blog.microcms.io" or not r["key"] for r in seen):
    bad(f"a request was not for e2e-blog.microcms.io with the key: {[r for r in seen if r['host'] != 'e2e-blog.microcms.io' or not r['key']][:2]}")
def asked(path, **q): return any(r["path"] == path and all(r["q"].get(k) == v for k, v in q.items()) for r in seen)
for path, q in (("/api/v1/blog", {"limit": "10"}), ("/api/v1/blog", {"offset": "10"}),
                ("/api/v1/blog/post-05", {"draftKey": "e2e-draft"}), ("/api/v1/blog", {"filters": "tags[contains]tag-edge"}),
                ("/api/v1/blog", {"q": "post 07"}), ("/api/v1/tags", {"limit": "10"}), ("/api/v1/tags/tag-edge", {})):
    if not asked(path, **q):
        bad(f"the Worker never asked {path} with {q}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   the ten newest posts and page 2, post-03 with its writer, thumbnail and highlighting, a draft by its key and")
print(f"   never cached, a tag, a search and two 404s — {len(seen)} requests to e2e-blog.microcms.io, every one with the key")
PY

echo "e2e.test.sh: ok"
