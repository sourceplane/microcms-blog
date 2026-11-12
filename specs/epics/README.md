# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`microcms-blog/`](./microcms-blog/) | **MC** | In progress (MC1: the site on Workers) | Vercel's Next.js Blog with microCMS on Cloudflare Workers + Static Assets through OpenNext, the service and its key read per request from the Worker, deployable before a microCMS service exists, and an Orun baseline that instantiates it in one landing (MC2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
