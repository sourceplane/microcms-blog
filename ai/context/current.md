# microcms-blog — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a blog built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Next.js Blog with microCMS (microCMS's Simple Blog template) on
Cloudflare Workers + Static Assets (`@opennextjs/cloudflare`) — posts, tags
and writers read through microCMS's SDK, rendered on request, code blocks
highlighted on the server, posts by tag, full-text search, drafts by their
draft key — packaged as an Orun baseline: `orun new --blueprint
repo-blueprint.yaml` builds a new blog in its own repository and takes it to
live on stage and prod in one landing (`01-product`), then records what went
live (`02-docs`). It deploys before its owner has a microCMS service:
unconnected, the blog serves sample posts under a "not connected" notice.
The service and its API key are the Worker's secrets, read per request and
never built in. There is no infra component; microCMS stays the owner's SaaS.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` (MC2 — the baseline, one landing) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI, unconnected and connected to a local stand-in for microCMS's content API; a live bootstrap (risk MC-A) and a blog reading a real microCMS service (risk MC-B) are still to come |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/microcms-blog/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/microcms-blog/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/microcms-blog/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one blog from `baseline-v1` against a workspace, and record its
   timings (closes MC-A).
2. Connect a microCMS service to it, see the samples give way, and open one
   draft through the service's screen preview (closes MC-B).
