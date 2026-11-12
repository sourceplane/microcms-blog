# microcms-blog — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | OpenNext on Workers + Static Assets (`cloudflare-workers-assets-turbo`), the static-assets incremental cache; no R2 or Durable Object cache | Nothing in the Worker is revalidated | `specs/epics/microcms-blog/design.md` §2 |
| 2 | The layout is `force-dynamic`: every page renders per request; microCMS's CDN is the cache | The microCMS key is the Worker's, so no build can pre-render a page from the service | design.md §2, risk MC-C |
| 3 | The unconnected blog: no service ID or API key in the Worker serves sample posts under a notice — nothing throws | The platform brokers Cloudflare, not microCMS, so a bootstrap deploys before the owner has a service (cms-contentful's pattern); the template threw at module load | design.md §3 |
| 4 | `MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY` are `optionalSecretEnv`, unset for the build (`env -u`) and pushed to the Worker as secrets after it (`tooling/wire/worker-secrets.mjs`); read per request from `getCloudflareContext().env` | A required ref fails the lane before its first step on a fresh product; a key read per request never sits in a bundle (algolia-search's pattern) | risk MC-E |
| 5 | The template's `proxy.ts` becomes a second `headers()` rule (`/blogs/:path*` with `?dk=` → no-store) | OpenNext runs a Node proxy only experimentally, and appended its header to the catch-all `headers()` value instead of replacing it | design.md §2 |
| 6 | The template's SDK is used unchanged; the e2e reaches a stand-in through its own Worker entry that rewrites `*.microcms.io` requests | microcms-js-sdk (3.5 and 3.6) has no host or fetch option, and a test seam does not belong in the product | design.md §6 |
| 7 | Setting a microCMS secret redeploys nothing; the owner redeploys by hand or with the `# orun: redeploy` stamp | `orun plan --changed` plans a component only when its files change, and the deploy is what pushes the secrets | risk MC-D |
| 8 | Next 16.4.5 (the template's 16.4 line) with @opennextjs/cloudflare 1.20.16, both pinned | 1.20.16's peer range is `>=15.5.29 <16 || >=16.4.5` | risk MC-G |
| 9 | Two phases, one landing (`01-product`, `02-docs`), no infra component | A landing has a fixed cost (cirrus-baseline since baseline-v22); the blog provisions nothing | design.md §5 |
| 10 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; stack-tectonic 0.19.0, not 0.20.0 | A bootstrap cannot set a repository variable; Turbopack refuses 0.20.0's out-of-tree `node_modules` | risk MC-I |
| 11 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph and bindings drifts silently | `tooling/catalog/gen-component-docs.py` |
| 12 | The workers.dev subdomain is read from the Cloudflare connection; the console asks for no domain, and an empty `productdomain` brands the placeholder `<reponame>.example.com` | One right answer for the subdomain; a domain is an owner's step after the bootstrap | `blueprint.yaml`, `tooling/rebrand/rebrand.mjs` |
| 13 | The deployment-record hook uses the Python standard library only, tested without PyYAML | The console's build box has python3 but not PyYAML (orun-cloud#2344) | `testing/render.test.sh` |
