# microcms-blog

Vercel's [Next.js Blog with microCMS](https://github.com/microcmsio/simple-blog-with-microcms)
— microCMS's Simple Blog template: posts, tags and writers in a microCMS
service read through its SDK, code blocks highlighted on the server with
highlight.js, posts by tag, full-text search, pages of ten, and drafts
previewed by their draft key — running on **Cloudflare Workers + Static
Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare),
and packaged as an **Orun baseline**: one command takes a new blog from
nothing to live on stage and prod, in its own repository, under its own
name — in ONE landing. It goes live before its owner has a microCMS service
at all.

The template's code is the code and microCMS stays the SaaS it is. What the
port adds is the Workers build, the monorepo wrapper, a test package and the
deploy contract; what it changes is what Workers force:

- **Credentials:** the microCMS service and its API key are the Worker's,
  read per request and never in a build, so every page renders on request.
- **Caching:** the template's Node `proxy.ts`, which marked a draft
  uncacheable, is now a `headers()` rule. On Workers that proxy is
  experimental, and its header was appended to the catch-all one instead of
  replacing it.

What the baseline adds is everything needed to make a copy of it somebody
else's — built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is. What
makes it deployable with no microCMS service is the port's: an unconnected
blog renders sample posts under a visible "not connected" notice instead of
failing (the template threw at module load). See
[`specs/epics/microcms-blog`](specs/epics/microcms-blog/README.md) for the
design, the milestones and the as-built status.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/microcms-blog
cd microcms-blog
orun new --blueprint repo-blueprint.yaml --out ~/blogs/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`microcms-blog` → Build). Two phases — `01-product` (the repository, its CI and
the whole blog in one pull request, deployed to stage and prod by one
convergence, smoke-tested) and `02-docs` (the live deployment recorded) —
each landing one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **blog only** — the app, its tests, its CI,
its tooling, a README of its own and its operating contract — renamed
throughout to the blog's name, repository and Cloudflare Worker. None of this
repository's machinery ships, and nothing that ships names it.

The only provider the bootstrap asks for is Cloudflare. **microCMS is not a
provider the platform brokers**, so the blog is built without it and its
owner connects a service afterwards:
- the three list APIs (`tags`, `writers`, `blog`), as
  `apps/web/microcms-template.json` exports them;
- two optional Orun secrets, `MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY`;
- a redeploy, which pushes both to the Worker as secrets.

The blog's README, "Connect microCMS" (`.baseline/product/README.md` here),
has the steps.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer, and its test without PyYAML | `hooks/render-deployment-docs.sh`, `testing/render.test.sh` |
| The blog's README and context pack | `.baseline/product/README.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end (with a local microCMS stand-in) | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the site)

| Surface | Where |
|---|---|
| Home, `/p/[current]`, `/blogs/[slug]`, `/tags/[tagId]` (and its pages), `/search` (and its pages) | `apps/web/app` |
| The microCMS reads, the SDK's client created per request, with the sample fallback | `apps/web/libs/microcms.ts`, `apps/web/libs/sample.ts` |
| The "not connected" notice and the sample writer's picture | `apps/web/components/ConnectMicroCMS`, `apps/web/public/sample` |
| Rich text and code highlighting, dates | `apps/web/libs/utils.ts` |
| The template's components (header, nav, search, lists, pagination, tags, article) | `apps/web/components` |
| The three APIs, as microCMS exports them | `apps/web/microcms-template.json` |
| The blog's name (the rename's seam) | `apps/web/app/site.ts` |
| Workers build and deploy contract | `apps/web/next.config.js`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml`, `tooling/wire/worker-secrets.mjs` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
pnpm --filter @app/web preview   # wrangler dev over the built Worker: the sample posts, unconnected
```

That much needs no microCMS service: the baseline's own e2e tier
(`testing/e2e.test.sh`) runs exactly this on each landing before a tag, and
a blog's developers run it before a push — a blog's pull request builds and
dry-deploys it, and does not lint or run the tests. To see your own content:

```bash
cd apps/web
cp .env.example .env.local        # MICROCMS_SERVICE_DOMAIN, MICROCMS_API_KEY
cd ../..
pnpm --filter @app/web dev        # http://localhost:3000
```

For the Worker locally, the service and its key are Worker secrets:

```bash
cd apps/web
cp .dev.vars.example .dev.vars    # MICROCMS_SERVICE_DOMAIN, MICROCMS_API_KEY
pnpm build
pnpm preview                      # wrangler dev over the built Worker
```

| Variable | Where it is read | What it does |
|---|---|---|
| `MICROCMS_SERVICE_DOMAIN` | request time, in the Worker (`getCloudflareContext().env`; `process.env` under `next dev`) | The service ID. A deploy pushes its environment's `MICROCMS_SERVICE_DOMAIN` secret to the Worker, best-effort; the build never has it. Unset, the blog is unconnected: the sample posts under a notice. |
| `MICROCMS_API_KEY` | request time, likewise | The service's API key; needed with the service ID to connect. |
| `BASE_URL` | build time (`next.config.js` inlines it) | The site's public origin, for `metadataBase` (Open Graph and canonical URLs). The deploy sets it per environment: `SITE_URL` when `intent.yaml` sets one, else the Worker's workers.dev URL. |

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting (pre-rendered pages, the Node `proxy.ts`, route handlers) | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; every page renders on request (the layout is `force-dynamic`: the build has no microCMS key) |
| Project env vars (`MICROCMS_API_KEY`, `MICROCMS_SERVICE_DOMAIN`, `BASE_URL`) read by the build and the server | The service and its key: optional Orun secrets, unset for the build (`env -u`) and pushed to the Worker as secrets after it (`tooling/wire/worker-secrets.mjs`), read per request. `BASE_URL`: set per environment by the deploy |
| A missing key throws at module load: every page a 500 | An unconnected blog: sample posts and a notice — deployable before a microCMS service exists |
| `proxy.ts` sets `CDN-Cache-Control: no-store` on a draft (`/blogs/*?dk=`) | A second `headers()` rule in `next.config.js`, after the template's catch-all one (OpenNext runs a Node proxy only experimentally, and appended its header to the catch-all's) |
| Vercel's CDN honours `CDN-Cache-Control` (60 s, then 300 s stale) | The header is kept for a CDN in front; Cloudflare does not cache a Worker's responses on workers.dev, so every view reads microCMS, whose own CDN fronts its API |
| A microCMS webhook rebuilding the site (the template's `repository_dispatch` placeholder workflow) | Nothing to rebuild: a published post shows on the next visit. The placeholder workflow is not carried |
| `next/image` for the logo, the clock and the placeholder image | Unchanged, unoptimised (`images.unoptimized`): the Worker carries no image optimiser; microCMS's images keep their image-API query strings |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` and smoke-tests it (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## CI

| Workflow | What it runs | Ships to a blog |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a blog carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the blog built and dry-deployed per environment; they do not lint or run the tests), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests (the deployment record rendered without PyYAML among them) and the component docs' drift check, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, each landing installed, its fixture rendered, type-checked, linted, tested and built, then the blog built in a staged job tree with the microCMS secrets set and kept out of the build, dry-deployed, and served — with no microCMS service, then connected to a local stand-in for its content API | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
