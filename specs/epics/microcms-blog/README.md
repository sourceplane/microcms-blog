# microcms-blog — Vercel's Next.js Blog with microCMS on Cloudflare Workers

**microCMS's Simple Blog, rendered on request by one Cloudflare Worker from a
microCMS service — its static assets beside it, the service and its key the
Worker's secrets — deployed by Orun to stage and prod on every merge, live
before its owner has a service at all, and the baseline that makes a copy of
it somebody else's blog in one landing.**

| | |
|---|---|
| Status | ✅ Shipped (`baseline-v1`) — proven offline in Baseline CI, unconnected and connected to a local stand-in for microCMS's content API; not yet live (risk MC-A) |
| Upstream | [microcmsio/simple-blog-with-microcms](https://github.com/microcmsio/simple-blog-with-microcms) (MIT, © 2023 microCMS), at `4077da9` (2026-11-11) — Vercel's "Next.js Blog with microCMS" template |
| Reference | [cms-contentful](https://github.com/sourceplane/cms-contentful) — the same scaffolding, tests, bootstrap and unconnected sample mode; [algolia-search](https://github.com/sourceplane/algolia-search) — keys pushed to the Worker after the build and read per request |
| Key | `MC` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, what the spike proved, the unconnected blog, the repository and
   the build, and the alternatives rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| MC0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | MC-1 |
| MC1 — the blog on Workers | the template in `apps/web`, built by OpenNext into one Worker, the keys read per request, its unconnected sample mode; `tests/web` | MC-2 |
| MC2 — a baseline | the console card, the build document, the context pack and the baseline's tests | MC-3 |
