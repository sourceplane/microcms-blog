# microcms-blog — operating contract (for humans and agents)

This is the standing guide to how this blog is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the blog without any
other source.

## What this system is

A blog whose content lives in [microCMS](https://microcms.io), served from
Cloudflare, expressed as an Orun component-native desired-state repo.

- **`apps/web`** — Next.js built by `@opennextjs/cloudflare` into one Worker
  plus Static Assets. `/`, `/p/<n>`, `/blogs/<id>`, `/tags/<id>` and
  `/search?q=` render per request from microCMS's content API through
  `microcms-js-sdk` (its CDN is the cache); `/blogs/<id>?dk=<draft key>`
  reads a draft and is never cached.
- **`tests/web`** — vitest over the microCMS reads and their sample fallback,
  the rich-text highlighting, the template's components, the cache headers
  and the sample content. No lane lints or runs the tests: a pull request
  builds and dry-deploys the blog, so run `pnpm typecheck && pnpm lint &&
  pnpm test` before you push.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  wrangler renderer for a deployable that comes to take wiring.

There is no infrastructure component: microCMS is a hosted service the
blog reads over HTTPS, not something this repository provisions.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and dry-deploy, nothing deploys.

## microCMS: connected, or sample posts

The blog reads ONE microCMS service per environment: its service ID and API
key are Worker secrets, read on every request (`apps/web/libs/microcms.ts`),
and never in a build. Until the Worker has both it is **unconnected**: every
page renders the sample posts in `apps/web/libs/sample.ts` under a "not
connected" notice. Nothing fails: an unconnected blog deploys, passes its
smoke test and serves.

To connect it:

```bash
# 0. once per service: the three list APIs the blog reads — tags (name),
#    writers (name, profile, image) and blog (title, description, content,
#    thumbnail, tags → tag, writer → writer), as apps/web/microcms-template.json
#    exports them (README, "Connect microCMS", has every field)

# 1. per deployed environment: the service ID and its API key
orun secrets set MICROCMS_SERVICE_DOMAIN --env stage    # prompts for the value
orun secrets set MICROCMS_API_KEY        --env stage
# …and the same with --env prod

# 2. redeploy apps/web: the deploy pushes both to the Worker as secrets
#    (tooling/wire/worker-secrets.mjs), and setting a secret deploys nothing.
#    Deploy by hand, or change the stamp on the last line of
#    apps/web/component.yaml (`# orun: redeploy <reason> <stamp>`) and merge.
```

Drafts: in microCMS, the blog API's screen preview URL is
`https://microcms-blog-web-<env>.your-workers-subdomain.workers.dev/blogs/{CONTENT_ID}?dk={DRAFT_KEY}`
(or the custom domain).

The service's secrets are read best-effort (`optionalSecretEnv` in
`apps/web/component.yaml`): a key nobody has stored is skipped, never a
failed lane. A wrong service ID or key is not caught at deploy: microCMS
refuses the reads and every page is the template's 404, so probe `/` after
connecting.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` checks its committed `wrangler.jsonc` is there, builds once per
   environment with no microCMS value in its environment (`env -u`), pushes
   that environment's microCMS secrets to the Worker (if any), `wrangler
   deploy` ships `microcms-blog-web-<env>`, and a smoke test fetches `/` and
   requires the footer's "All Rights Reserved", then requires an article
   that does not exist to be a 404 — proof the Worker's server code
   answers.
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane passed. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing deploys: the blog builds and dry-deploys.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "blog
  converged"; probe the URLs instead.
- Published content needs no deploy: the blog reads microCMS on every
  request, so a published post shows on the next visit.
- A change to `intent.yaml`'s `environments`, or to an Orun secret, maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web`.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (the
  `workers-deploy` scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per
  run from the workspace's Cloudflare connection. No long-lived values at
  rest; nothing to rotate by hand.
- **The microCMS service**: `MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY`
  on `stage` and `prod`, stored by the owner, pushed to the Worker as
  secrets by each deploy and read per request; no build sees them. Kept as
  secrets so each environment can name its own service.
- Inspect by NAME only: `orun secrets list --org <ws> --env stage|prod`. No
  tooling in this repository prints a secret value, and no document in
  `ai/context/` may contain one.

## Verifying the system

```bash
# the blog on each environment (also recorded, probed, in deployment.md);
# an unconnected blog carries data-microcms-notice="unconnected"
curl -s https://microcms-blog-web-stage.your-workers-subdomain.workers.dev/ | grep -o 'data-microcms-notice="[a-z]*"'
curl -s -o /dev/null -w '%{http_code}\n' https://microcms-blog-web-prod.your-workers-subdomain.workers.dev/
curl -s -o /dev/null -w '%{http_code}\n' https://microcms-blog-web-prod.your-workers-subdomain.workers.dev/blogs/no-such-post   # 404

# workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect a microCMS service | "microCMS: connected, or sample posts" above |
| write, edit, publish | in microCMS's web app; a published post is live on the next visit, no deploy needed |
| preview a draft | microCMS's screen preview on the post, which opens `/blogs/<id>?dk=<draft key>` |
| change the blog's code | edit `apps/web` (its name: `apps/web/app/site.ts`), merge |
| change the content model | in microCMS, then the types in `apps/web/libs/microcms.ts` and the components that render them; export the APIs to `apps/web/microcms-template.json` |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), set `SITE_URL` in that environment's `env:` in `intent.yaml`, point microCMS's screen preview at it, then replace the placeholder `microcms-blog.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod) with it |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Structural changes follow the same contract that deployed the blog: add a
component under `apps/`, `infra/` or `packages/` with a `component.yaml`,
land it as a pull request, and the convergence run deploys it. A component
under `infra/` whose wiring the Worker reads is declared in `apps/web`'s
`dependsOn` (enforced on `main`), so it is applied first.
