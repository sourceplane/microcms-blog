#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — a source link, the site-name seam, the Worker name in wrangler.jsonc
# and the component, the intent's environment URLs, the placeholder domain, the
# microCMS secret refs, and the upstream template's links and microCMS's own
# variable names, which name microCMS but not the slug and must NOT be renamed —
# and each can run through several passes (a re-run of a phase
# re-runs the rebrand over everything already placed, and 02-docs's heal runs
# it again), so a value written by one pass must survive every later one.
#
# The identity is PINNED (fixtures/baseline-identity.microcms-blog.json) rather than
# read from .baseline/identity.json: what this tests is the engine, and its
# fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.microcms-blog.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the blog's own identity"
check "a source link names the product's owner and repository" \
  "$acme" README.md \
  'See https://github.com/sourceplane/microcms-blog for the source.' \
  'See https://github.com/acme-inc/acme-notes for the source.'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/app/site.ts 'export const SITE_NAME = "Simple Blog";' \
  'export const SITE_NAME = "Acme Notes";'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-notes","productname":"Sam'"'"'s Notes & Links","productdomain":"sam.dev"}' \
  apps/web/app/site.ts 'export const SITE_NAME = "Simple Blog";' \
  'export const SITE_NAME = "Sam'"'"'s Notes & Links";'
check "the template's name elsewhere is content, and is left alone" \
  "$acme" apps/web/README.md '# Simple Blog with microCMS, on Workers' \
  '# Simple Blog with microCMS, on Workers'
check "the upstream template's links name microCMS, not the slug, and are not renamed" \
  "$acme" README.md \
  'Vercel'"'"'s [Next.js Blog with microCMS](https://github.com/microcmsio/simple-blog-with-microcms) (demo: https://simple-blog-with-microcms.vercel.app/)' \
  'Vercel'"'"'s [Next.js Blog with microCMS](https://github.com/microcmsio/simple-blog-with-microcms) (demo: https://simple-blog-with-microcms.vercel.app/)'
check "…nor is microCMS's schema export, beside a renamed Worker" \
  "$acme" README.md \
  'import apps/web/microcms-template.json, then wrangler secret put X --name microcms-blog-web-stage' \
  'import apps/web/microcms-template.json, then wrangler secret put X --name acme-notes-web-stage'
check "the Worker name in wrangler.jsonc is re-prefixed" \
  "$acme" apps/web/wrangler.jsonc '  "name": "microcms-blog-web",' \
  '  "name": "acme-notes-web",'
check "the component's worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml '    workerName: microcms-blog-web' \
  '    workerName: acme-notes-web'
check "the workers.dev subdomain in the component" \
  "$acme" apps/web/component.yaml '    workersDevSubdomain: your-workers-subdomain' \
  '    workersDevSubdomain: acme'
check "an environment URL in the intent" \
  "$acme" intent.yaml '    url: https://microcms-blog-web-prod.your-workers-subdomain.workers.dev' \
  '    url: https://acme-notes-web-prod.acme.workers.dev'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: microcms-blog.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-notes","productname":"Acme Notes","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: microcms-blog.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: microcms-blog.example.com' \
  '      BASE_DOMAIN: acme-notes.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "microcms-blog",' \
  '  "name": "acme-notes",'
check "a microCMS secret ref names the product's workspace and project, the environment kept" \
  "$acme" apps/web/component.yaml \
  '    MICROCMS_SERVICE_DOMAIN: "secret://microcms-blog/microcms-blog/{{ .environment }}/MICROCMS_SERVICE_DOMAIN"' \
  '    MICROCMS_SERVICE_DOMAIN: "secret://ws_79BDXAZQ/acme-notes/{{ .environment }}/MICROCMS_SERVICE_DOMAIN"'
check "the microCMS variable names are microCMS's, and are left alone" \
  "$acme" apps/web/.env.example 'MICROCMS_API_KEY=' \
  'MICROCMS_API_KEY='
check "…in the build command too, beside the renamed Worker" \
  "$acme" apps/web/component.yaml \
  '    buildCommand: env -u MICROCMS_SERVICE_DOMAIN -u MICROCMS_API_KEY x && node worker-secrets.mjs --secret MICROCMS_API_KEY --worker "microcms-blog-web-${ORUN_ENVIRONMENT}"' \
  '    buildCommand: env -u MICROCMS_SERVICE_DOMAIN -u MICROCMS_API_KEY x && node worker-secrets.mjs --secret MICROCMS_API_KEY --worker "acme-notes-web-${ORUN_ENVIRONMENT}"'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg a source link keeps the baseline's owner" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev"}' \
  README.md 'https://github.com/sourceplane/microcms-blog' \
  'https://github.com/sourceplane/acme-notes'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"microcms-blog-2","productname":"Simple Blog 2","productdomain":"microcms-blog.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "microcms-blog",' \
  '  "name": "microcms-blog-2",' 3
check "a Worker name built on it survives three passes" \
  "$contains" apps/web/wrangler.jsonc '  "name": "microcms-blog-web",' \
  '  "name": "microcms-blog-2-web",' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: microcms-blog.example.com' \
  'BASE_DOMAIN: microcms-blog.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" intent.yaml '    url: https://microcms-blog-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://microcms-blog-2-web-stage.your-workers-subdomain-2.workers.dev' 3
check "a blog name containing the baseline's name survives three passes" \
  "$contains" apps/web/app/site.ts 'export const SITE_NAME = "Simple Blog";' \
  'export const SITE_NAME = "Simple Blog 2";' 3
check "the upstream repository's link survives three passes of a slug that contains the baseline's" \
  "$contains" README.md 'https://github.com/microcmsio/simple-blog-with-microcms' \
  'https://github.com/microcmsio/simple-blog-with-microcms' 3
# The fixture the placement and end-to-end gates build with: a slug that ENDS
# in the baseline's, so its Worker is `<…>-microcms-blog-web`.
suffixed='{"reponame":"acme-microcms-blog","productname":"Acme","productdomain":"blog.acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'
check "a repo slug ending in the baseline's slug survives three passes" \
  "$suffixed" package.json '  "name": "microcms-blog",' \
  '  "name": "acme-microcms-blog",' 3
check "…and its Worker name" \
  "$suffixed" apps/web/wrangler.jsonc '  "name": "microcms-blog-web",' \
  '  "name": "acme-microcms-blog-web",' 3
check "…and its secret ref" \
  "$suffixed" apps/web/component.yaml '    X: "secret://microcms-blog/microcms-blog/{{ .environment }}/MICROCMS_API_KEY"' \
  '    X: "secret://ws_79BDXAZQ/acme-microcms-blog/{{ .environment }}/MICROCMS_API_KEY"' 3
# The placement fixture carries no domain (a console build asks for none), and
# its slug's placeholder CONTAINS the baseline's: acme-microcms-blog.example.com.
nodomain='{"reponame":"acme-microcms-blog","productname":"Acme","productdomain":"","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'
check "…and, with no domain, its placeholder survives three passes" \
  "$nodomain" intent.yaml '      BASE_DOMAIN: microcms-blog.example.com' \
  '      BASE_DOMAIN: acme-microcms-blog.example.com' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "microcms-blog-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "microcms-blog-2"' fail
verify "given the values, a slug ending in the baseline's passes" \
  "$suffixed" apps/web/wrangler.jsonc '"name": "acme-microcms-blog-web"' pass --values
verify "given the values, a placeholder domain containing the baseline's passes" \
  "$nodomain" intent.yaml 'BASE_DOMAIN: acme-microcms-blog.example.com' pass --values
verify "the upstream template's links are not residue" \
  "$acme" README.md 'https://github.com/microcmsio/simple-blog-with-microcms https://simple-blog-with-microcms.vercel.app/' pass --values
verify "microCMS's variable names are not residue" \
  "$acme" apps/web/.env.example 'MICROCMS_SERVICE_DOMAIN= MICROCMS_API_KEY=' pass --values
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "microcms-blog"' fail --values
verify "a leftover Worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "microcms-blog-web"' fail --values
verify "a leftover link to another repository named like it fails" \
  "$acme" README.md 'https://github.com/acme-inc/microcms-blog' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/x.ts 'export class MicrocmsBlog {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-notes"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "MICROCMS_BLOG_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
