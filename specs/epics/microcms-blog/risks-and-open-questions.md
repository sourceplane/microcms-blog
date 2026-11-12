# microcms-blog — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| MC-A | `baseline-v1` is not yet proven live | OPEN | Proven offline in Baseline CI: the offline bootstrap with the blueprint's own hooks, the stage lane's own steps in a staged job tree (with the microCMS secrets set and kept out of the build), the blog served by `wrangler dev` and smoke-tested with the component's own command. A console bootstrap closes it, including the first `wrangler secret bulk` from a deploy lane |
| MC-B | No real microCMS service has been read | OPEN | The connected path is proven against a local stand-in in the shapes `microcms-template.json` defines (list, detail, tag filter, search, draft key, the key checked). The first connected product closes it |
| MC-C | Every page view is a content-API request | ACCEPTED | The layout reads the tags and each page its posts; microCMS's CDN answers them, and its plan's limits apply. Cloudflare does not cache a Worker's responses on workers.dev; a busy blog's upgrade is a cache in the Worker or a custom domain with the Cache API |
| MC-D | Setting a secret redeploys nothing | ACCEPTED | The deploy is what pushes the secrets to the Worker; the owner redeploys by hand or with the `# orun: redeploy` stamp in `apps/web/component.yaml` (README, "Connect microCMS") |
| MC-E | The API key is a Worker secret | ACCEPTED | Read per request by server code only; no bundle or browser carries it (the e2e greps the build for it). Use a key with GET permission only, as microCMS's default key is |
| MC-F | A draft's `no-store` depends on Next's header precedence | ACCEPTED | The later `headers()` rule wins for the same key; `tests/web` pins the rules and the e2e reads the header, unconnected and connected |
| MC-G | Next 16.4.5 and @opennextjs/cloudflare 1.20.16 move together | WATCH | Each OpenNext release raises its Next floor (1.20.16: `>=16.4.5` on the 16 line); bump both in one change |
| MC-H | A wrong service ID or key makes every page the 404 page | ACCEPTED | As upstream: the SDK's refused read is `notFound()`, and the layout reads `tags` on every page. BOOTSTRAP.md's troubleshooting names the causes |
| MC-I | stack-tectonic 0.19.0, not 0.20.0 | ACCEPTED | 0.20.0's lane-shared install links each job's `node_modules` out of its tree, which Turbopack refuses |
| MC-J | The e2e's entry relies on Next capturing the global fetch when its server starts | WATCH | Test-only: if OpenNext changes how it loads the server, `testing/lib/e2e-worker.mjs` follows; the connected checks fail loudly if the stand-in sees nothing |
| MC-K | The local tiers ran on Node 26 | ACCEPTED | Homebrew's node@22 is broken on the build machine; Baseline CI runs Node 22, and the template's packages all admit it |
