# microcms-blog — design

## 1. The template

Vercel's "Next.js Blog with microCMS" is microCMS's own
[Simple Blog](https://github.com/microcmsio/simple-blog-with-microcms)
(Next.js 16 App Router, React 19, CSS Modules): a blog whose content is in a
microCMS service's three **list** APIs — `tags` (a name), `writers` (name,
profile, image) and `blog` (title, description, rich-text content,
thumbnail, tags, writer), exported in `microcms-template.json`. The home page
and `/p/<n>` list ten posts a page; `/blogs/<id>` renders one, its rich-text
HTML's code blocks highlighted on the server with highlight.js through
cheerio, with its writer and tags; `/tags/<id>` and `/search?q=` (microCMS's
full-text search) list posts with their own pages. Every read goes through
`microcms-js-sdk` (`libs/microcms.ts`), which threw at module load without
`MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY`. A draft opens at
`/blogs/<id>?dk=<draft key>`. `next.config.js` sets `CDN-Cache-Control`
(60 s, then 300 s stale) on every route, and a Node `proxy.ts` (Next 16's
middleware) replaced it with `no-store` on a draft.

## 2. How it maps to Cloudflare

| Vercel | Here | Why |
|---|---|---|
| Next.js hosting | One Worker built by `@opennextjs/cloudflare` (`output: 'standalone'`), `public/` and the client chunks in its Static Assets, the static-assets incremental cache | Nothing in the Worker is revalidated |
| Env vars read by the build and the server; pages pre-rendered from the service at build | The service and its key: optional Orun secrets, unset for the build (`env -u`), pushed to the Worker as secrets after it (`tooling/wire/worker-secrets.mjs`) and read per request from `getCloudflareContext().env`; the layout `force-dynamic` | No bundle carries a key; a key stored or rotated later reaches the Worker on the next deploy without a build seeing it |
| `proxy.ts` (Node runtime) | A second `headers()` rule (`/blogs/:path*` with `has: query dk`), after the template's catch-all | OpenNext builds a Node proxy only experimentally ("not officially maintained"), and under it the proxy's header was appended to the catch-all's (`no-store, must-revalidate, public, s-maxage=60, …`); the later `headers()` rule replaces it |
| Vercel's CDN honours `CDN-Cache-Control` | The header is kept; nothing caches on workers.dev | A Worker's responses are not cached by Cloudflare's CDN on workers.dev; microCMS's CDN fronts its content API |
| `next/image` for three local files | `images.unoptimized` | No optimiser in the Worker; microCMS's images keep their image-API query strings |
| `BASE_URL` in the dashboard | `BASE_URL` inlined at build by `next.config.js`, set per environment by the deploy (`SITE_URL` or the workers.dev URL) | The origin is no secret, and every page needs it |

**What the spike proved** (Next 16.4.5, OpenNext 1.20.16, `wrangler dev`):
OpenNext 1.20.16's peer range is `>=15.5.29 <16 || >=16.4.5`, so the
template's 16.4 line stays, at 16.4.5. cheerio 1.2 and highlight.js 11 run on
workerd. The SDK client created per request reads a stand-in's list, detail,
tag filter, search and draft key, with the key in `X-MICROCMS-API-KEY`. The
Worker is 1.9 MiB gzipped, inside Workers Free's 3 MiB.

## 3. The unconnected blog

The platform brokers Cloudflare, not microCMS, so a bootstrap deploys a blog
whose owner has no service yet. Upstream would throw at module load and
every page would be a 500. Here, while the Worker lacks either value,
`libs/microcms.ts` hands every read to `libs/sample.ts`: a client with the
SDK's `getList` and `getListDetail` over three posts, two tags and a writer
in the template's API shapes (limit, offset, the tag filter and the search
included, an unknown id a 404). The layout shows a "not connected" notice
(`data-microcms-notice="unconnected"`), and the first post is the connect
steps. cms-contentful's pattern, kept to the same shape: the e2e tier and the
deployment record read the notice.

## 4. The repository

cms-contentful's shape (turso v8): `apps/web` (type
`cloudflare-workers-assets-turbo`, lane `isolated`) and `tests/web` (type
`turbo-package`, a vitest suite run on the `dev` rung). No infrastructure:
microCMS is a hosted service. The blog's name is one seam, `SITE_NAME` in
`app/site.ts`, read by the title template, the Open Graph title, the logo's
alt text and the footer. The upstream template's links name microCMS but not
this slug, so the rename engine needs no protection for them.

## 5. The build

`next build` (Turbopack), `opennextjs-cloudflare build --skipBuild`, then
`populateCache local`; the component's build step then runs
`worker-secrets.mjs`, which is a no-op in a verify lane (no Cloudflare
credential) and pushes the resolved secrets in a deploy lane.
`repo-blueprint.yaml` is cms-contentful's: one landing (`01-product`)
places, brands and lands the whole tree, one convergence builds and deploys
stage and prod side by side, and `02-docs` records what went live. The smoke
checks the home page renders (its footer) and a missing article is a 404.

## 6. Testing the connected blog

microcms-js-sdk (3.5 and 3.6) builds `https://<service>.microcms.io/api/v1`
itself and calls the global `fetch`, with no host or fetch option. The
product keeps the SDK untouched; the e2e tier serves the SAME build behind
its own entry (`testing/lib/e2e-worker.mjs`), which wraps the global fetch
before the Worker's modules load and sends `*.microcms.io` requests to a
local stand-in (`testing/lib/fake-microcms.py`, the three APIs as microCMS
answers them, the key checked). `tests/web` covers the same reads with a
stubbed fetch.

## 7. Out of scope

- A cache in the Worker (OpenNext's R2 incremental cache, or the Cache API
  on a custom domain): an upgrade for a busy blog (risk MC-C).
- Creating the microCMS service or its APIs in the bootstrap: no platform
  connection holds microCMS credentials.

## 8. The alternatives rejected

- **Keys at build, pages pre-rendered (as on Vercel).** A build would need
  the service, which a fresh product lacks, and the key would sit in the
  bundle; a published post would need a rebuild to appear.
- **Keeping `proxy.ts`.** Experimental on OpenNext, and wrong there: its
  header was appended, not set.
- **A test seam in the product** (an env var pointing the SDK elsewhere).
  The SDK has no such option, and patching the product's fetch for tests
  would ship test code; the e2e's own entry does it outside the product.
