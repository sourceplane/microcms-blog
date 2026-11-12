# microcms-blog — implementation plan

Three milestones, each one reviewed pull request (MC0 is the repository's
first commit), each green before it merges.

## MC0 — the spec (MC-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (byte for byte turso-starter's, which plans nothing
until the workspace is set), the shared TypeScript and ESLint configuration,
the spec index, this doc set and the task contracts.

## MC1 — the blog on Workers (MC-2)

- The template's `app/`, `components/`, `constants/`, `libs/`, `public/`,
  `microcms-template.json`, ESLint and TypeScript configuration and LICENSE
  in `apps/web`; Next pinned to 16.4.5 with `@opennextjs/cloudflare` 1.20.16
  and `wrangler`.
- `next.config.js`: `output: 'standalone'`, the workspace root for the trace,
  `images.unoptimized`, `BASE_URL` inlined; the template's `headers()` kept
  and `proxy.ts`'s rule moved in. `open-next.config.ts` with the
  static-assets incremental cache; `wrangler.jsonc`; `cloudflare-env.d.ts`.
- `libs/microcms.ts`: the service and key read per request, the SDK client
  per request, the sample client when either is missing; the layout
  `force-dynamic`.
- The unconnected sample mode: `libs/sample.ts`, `public/sample`,
  `components/ConnectMicroCMS`.
- `SITE_NAME` in `app/site.ts`.
- `component.yaml`: the deploy contract, the service's optional secret refs
  unset for the build and pushed by `tooling/wire/worker-secrets.mjs`, and
  the smoke. `tests/web`: the reads and their fallback, the highlighting,
  the components, the cache headers and the sample content.
- The README's "How it maps to Vercel".

## MC2 — a baseline (MC-3)

cms-contentful's machinery, renamed: `blueprint.yaml`, `repo-blueprint.yaml`,
`.baseline/` (identity, the product's README with "Connect microCMS", task
contracts), `tooling/rebrand`, `tooling/bootstrap`,
`hooks/render-deployment-docs.sh` (standard library only; probing `/` and a
missing article, and recording whether each blog reads a service yet) with
`testing/render.test.sh`, `docs/phases/`, the context pack, `testing/` (the
leak and placement gates on this tree's files; the e2e tier reading every
route unconnected and then connected to `testing/lib/fake-microcms.py`
through `testing/lib/e2e-worker.mjs`) and `baseline.yml` / `tag.yml`.
