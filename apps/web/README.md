# Simple Blog with microCMS, on Workers

A blog whose content lives in microCMS, from Vercel's
[Next.js Blog with microCMS](https://github.com/microcmsio/simple-blog-with-microcms)
(microCMS's Simple Blog template, MIT, demo at
https://simple-blog-with-microcms.vercel.app/), running on Cloudflare Workers +
Static Assets:

- Posts, tags and writers in a microCMS service's three list APIs
  (`microcms-template.json`), read through `microcms-js-sdk`
  (`libs/microcms.ts`), the client created per request from the Worker's
  `MICROCMS_SERVICE_DOMAIN` and `MICROCMS_API_KEY`
- The post body is microCMS's rich-text HTML, its code blocks highlighted on
  the server with highlight.js (`libs/utils.ts`)
- `/p/<n>` pages of ten, `/tags/<id>`, `/search?q=` (microCMS's full-text
  search), and drafts at `/blogs/<id>?dk=<draft key>`
- Every page rendered on request by the Worker; the template's
  `CDN-Cache-Control` header (`next.config.js`), a draft never cached

Without the service and its key the blog is **unconnected**: it renders the
sample posts in `libs/sample.ts` under a notice that says how to connect. The
blog's name is in `app/site.ts`.

```bash
pnpm dev        # next dev on http://localhost:3000 (.env.local, or the sample posts)
pnpm build      # next build + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker (.dev.vars, or the sample posts)
```

How it is connected to a microCMS service and deployed — per environment, on
merge to `main` — is the repository's README and `component.yaml` beside this
file.
