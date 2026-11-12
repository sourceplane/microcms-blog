# microcms-blog

A blog whose posts, tags and writers live in a [microCMS](https://microcms.io)
service — read through microCMS's SDK, code blocks highlighted on the server,
posts by tag, full-text search, pages of ten, and drafts previewed by their
draft key — running on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare). It is
Vercel's [Next.js Blog with microCMS](https://github.com/microcmsio/simple-blog-with-microcms)
template (microCMS's Simple Blog), ported to Workers.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the blog uses into
[ai/context/deployment.md](ai/context/deployment.md); how the blog deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## Connect microCMS

The blog deploys and serves before it has a microCMS service: until its
Worker holds a service id and an API key it shows three **sample posts**,
under a notice that says so. To make it read your content:

1. **Create a service** at [app.microcms.io](https://app.microcms.io/signup)
   (the free Hobby plan is enough), choosing **Create your own**. Its
   **service ID** is the `xxxx` of `https://xxxx.microcms.io`.
2. **Add the three list APIs** the blog reads, all in the **list** format —
   `apps/web/microcms-template.json` is the template's own export of them:

   | API | Endpoint | Fields (field ID: kind) |
   |---|---|---|
   | tag | `tags` | `name`: text |
   | writer | `writers` | `name`: text, `profile`: text area, `image`: image |
   | blog | `blog` | `title`: text, `description`: text area, `content`: rich editor, `thumbnail`: image, `tags`: multiple content references → tag, `writer`: content reference → writer |

   Then write a tag, a writer and a post, and **publish** them (create the
   tag and the writer first: a post refers to them).
3. **Store the service and its key**, once per deployed environment: the
   service ID and the **default** API key from **API keys** (it reads
   published content; a draft needs its draft key as well). They are this
   repository's Orun secrets, and stage and prod can each name their own
   service:

   ```bash
   orun secrets set MICROCMS_SERVICE_DOMAIN --env stage   # prompts for the value
   orun secrets set MICROCMS_API_KEY        --env stage
   orun secrets set MICROCMS_SERVICE_DOMAIN --env prod
   orun secrets set MICROCMS_API_KEY        --env prod
   ```

4. **Redeploy the blog**: setting a secret deploys nothing. Use **Deploy by
   hand** below, or change the stamp on the last line of
   `apps/web/component.yaml` (`# orun: redeploy …`) and merge. The deploy
   pushes both to the Worker as secrets (`microcms-blog-web-stage`,
   `microcms-blog-web-prod`), never into a build, and every page reads them
   when it renders; the sample posts and the notice are gone from that deploy
   on.

**Drafts.** In microCMS, the blog API's **preview** setting (API settings →
Screen preview) takes the URL a draft opens at; point it at
`https://microcms-blog-web-prod.your-workers-subdomain.workers.dev/blogs/{CONTENT_ID}?dk={DRAFT_KEY}`
(and one for stage, or your custom domain). A page with `?dk=` reads the
draft, and is never cached.

Published changes show on the next visit: every page is rendered when it is
requested, from microCMS's content API, with no deploy and no webhook.

## What is here

| Surface | Where |
|---|---|
| Home, `/p/[current]`, `/blogs/[slug]`, `/tags/[tagId]`, `/search` | `apps/web/app` |
| The microCMS reads (the SDK's client, per request) | `apps/web/libs/microcms.ts` |
| The sample posts an unconnected blog shows, and its notice | `apps/web/libs/sample.ts`, `apps/web/public/sample`, `apps/web/components/ConnectMicroCMS` |
| Rich text and code highlighting, dates | `apps/web/libs/utils.ts` |
| The three APIs, as microCMS exports them | `apps/web/microcms-template.json` |
| The blog's name | `apps/web/app/site.ts` |
| Workers build and deploy contract | `apps/web/next.config.js`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # next build + opennextjs-cloudflare build → apps/web/.open-next
```

That needs no microCMS service, and is what to run before you push: a pull
request builds the blog but does not lint or run its tests. With a service:

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

| Variable | Read | What it does |
|---|---|---|
| `MICROCMS_SERVICE_DOMAIN` | request time, in the Worker | The service ID. Deployed Workers get it from the `MICROCMS_SERVICE_DOMAIN` secret of their environment, pushed by each deploy. Unset, the blog is unconnected: sample posts and a notice. |
| `MICROCMS_API_KEY` | request time, in the Worker | The service's API key. Both it and the service ID are needed to connect. |
| `BASE_URL` | build time | The site's public origin, for its Open Graph and canonical URLs. The deploy sets it per environment; not a secret. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The blog builds once per
environment — with no microCMS value in its environment, so no bundle can
carry one — then pushes that environment's microCMS secrets to the Worker
and deploys: to `stage`, then to `prod` once stage has converged on the same
commit; `dev` only verifies. The Worker is `microcms-blog-web-<env>` on your
account's workers.dev subdomain, and every deploy is smoke-tested over HTTP:
the home page must render, and an article that does not exist must be a
404. A pull request runs the same pipeline's verify lanes: the blog built
and dry-deployed for each environment, with nothing deployed and no secret
pushed. They do not lint or run the tests, so run `pnpm typecheck`,
`pnpm lint` and `pnpm test` before you push. (A push to `main` builds,
deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; nothing provider-shaped is stored in the repository
or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing or
rotating a microCMS secret, say. A component with nothing to run in that
environment (a test suite in `prod`) is left out with a notice.

**Caching.** The template's `CDN-Cache-Control` header (60 s, then 300 s
stale while it revalidates; a draft never) is kept for a CDN in front of the
blog. Cloudflare does not cache a Worker's responses on workers.dev, so as
deployed every view reads microCMS, whose own CDN fronts its content API.

## Custom domain

The blog answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the blog deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`microcms-blog-web-prod` → Settings → Domains & Routes → Add → Custom domain).
The blog's Open Graph and canonical URLs name its origin, so set
`SITE_URL: https://<your domain>` in that environment's `env:` in
`intent.yaml` — the next deploy builds with it — and point microCMS's draft
preview at it. The repository also names the domain as `BASE_DOMAIN` in
`intent.yaml` (dev, stage and prod), which the blog was born with as the
reserved placeholder `microcms-blog.example.com`. Replace it with your domain
in the same change.
