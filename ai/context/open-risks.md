# microcms-blog — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted ones, is
`specs/epics/microcms-blog/risks-and-open-questions.md`; this page lists only
what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| MC-A | Not proven live: repository creation, the brokered token, a real deploy, the secret push and the probes | OPEN | One bootstrap from a tag against a workspace |
| MC-B | No real microCMS service has been read: the connected path is proven against a local stand-in for the content API, in the shapes microcms-template.json defines | OPEN | The first connected product, its posts, a tag, a search and one draft through the screen preview |

Accepted, and worth knowing before you change them: MC-C (every page view
is a content-API request; Cloudflare does not cache a Worker's responses on
workers.dev), MC-D (setting a secret redeploys nothing), MC-H (a wrong
service ID or key makes every page the template's 404, as upstream).
