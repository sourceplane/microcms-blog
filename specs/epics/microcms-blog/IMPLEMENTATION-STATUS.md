# microcms-blog — implementation status

| Milestone | State | Landed |
|---|---|---|
| MC0 — the spec | ✅ | the repository's first commit, MC-1 |
| MC1 — the blog on Workers | ✅ | MC-2 |
| MC2 — a baseline | ✅ | MC-3, tagged `baseline-v1` |

The Worker is 7.9 MiB raw, 1.9 MiB gzipped (highlight.js is most of it) —
inside Workers Free's 3 MiB.

## Departures from the upstream template

Everything not listed here is the template as it is upstream at `4077da9`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace; the template's npm `package-lock.json` and `.npmrc` (npm 12's strict allow-scripts, a registry mirror, a minimum release age) are not carried; `engines.node` `26.x` → the workspace's `>=22` | One lockfile, `pnpm-lock.yaml`; the CI lanes run Node 22 |
| 2 | Next `^16.4.1` → `16.4.5` pinned, with `@opennextjs/cloudflare` 1.20.16 and `wrangler`; a fresh resolution gives microcms-js-sdk 3.6.0 and React 19.3.1 (the template's lock: 3.5.1, 19.3.0) | 1.20.16 accepts Next `>=16.4.5` on the 16 line |
| 3 | `next.config.js`: `output: 'standalone'`, `outputFileTracingRoot` at the workspace root, `images.unoptimized`, `env.BASE_URL`, `allowedDevOrigins` | The Workers build; the origin per environment; orun.work's live preview |
| 4 | `proxy.ts` removed; its rule (`/blogs/*?dk=` → `CDN-Cache-Control: no-store, must-revalidate`) is a second `headers()` entry | OpenNext's Node proxy is experimental and appended its header to the catch-all's (design §2) |
| 5 | `libs/microcms.ts` reads `MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY` per request from the Worker (`getCloudflareContext().env`, `process.env` without a context) and creates the SDK client per request; no throw at module load | The keys are the Worker's secrets, never the build's |
| 6 | The unconnected sample mode: `libs/sample.ts`, `public/sample/writer.svg`, `components/ConnectMicroCMS` in the layout | A fresh product has no service (design §3) |
| 7 | The root layout is `force-dynamic` | Every page renders on request; no build reads the service |
| 8 | `SITE_NAME` in `app/site.ts` is the title template and default, the Open Graph title, the logo's alt text and the footer's name (upstream: "Simple Blog" written twice in the metadata, "SIMPLE" in the alt text and the footer) | One rename seam |
| 9 | An article's canonical URL is `/blogs/<id>` (upstream: `/articles/<id>`, a route that does not exist) | A canonical URL must answer |
| 10 | ESLint: the template's flat config plus ignores for the build output; `typecheck` runs `next typegen && tsc --noEmit`; `tsconfig.json` excludes `.open-next` and `.wrangler`; `format` ignores the workspace's `.gitignore` | The workspace's `typecheck` / `lint` / `test` / `build` contract |
| 11 | `open-next.config.ts`, `wrangler.jsonc`, `cloudflare-env.d.ts`, `.env.example`, `.dev.vars.example` added | The Workers build; which values are Worker secrets |
| 12 | `.github/workflows/nextjs.yml` (a placeholder "Do Nothing" workflow on microCMS's `repository_dispatch`) and the template's `.vscode/` are not carried | `ci.yml` is the only push-to-main workflow; the workspace's `.vscode/` |
| 13 | `tests/web` (vitest) | The template ships none |
