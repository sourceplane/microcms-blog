#!/usr/bin/env python3
"""A local stand-in for microCMS's content API, for testing/e2e.test.sh.

    fake-microcms.py <port> <api-key>

Serves the template's three list APIs (apps/web/microcms-template.json: blog,
tags, writers) the way microCMS answers them — GET /api/v1/<endpoint> with
limit, offset, `filters=tags[contains]<id>`, `q` and `draftKey`, and
/api/v1/<endpoint>/<id> — and refuses a request without the right
X-MICROCMS-API-KEY with microCMS's 401. Every request is logged to stdout as
one JSON line: the host the Worker asked for (the e2e's wrapper sends it as
x-microcms-host), the path, the query and whether the key matched. Twelve
posts, so the blog has a second page; post-05 is a draft only its draft key
reads.
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

port, key = int(sys.argv[1]), sys.argv[2]


def meta(day):
    t = f"2026-10-{day:02d}T03:00:00.000Z"
    return {"createdAt": t, "updatedAt": t, "publishedAt": t, "revisedAt": t}


tags = [dict(id="tag-edge", name="edge", **meta(1)), dict(id="tag-cms", name="cms", **meta(1))]
writer = dict(id="writer-1", name="Stand-in Writer", profile="Writes the stand-in's posts.",
              image={"url": "https://images.microcms-assets.io/assets/e2e/writer.png", "width": 120, "height": 120},
              **meta(1))
blog = []
for i in range(12, 0, -1):  # newest first, as microCMS orders by publishedAt
    blog.append(dict(
        id=f"post-{i:02d}", title=f"Connected post {i:02d}", description=f"The stand-in's post number {i}.",
        content=("<p>Served by the stand-in &amp; rendered on Workers.</p>"
                 '<pre><code class="language-python">def answer():\n    return 42</code></pre>'),
        thumbnail=({"url": f"https://images.microcms-assets.io/assets/e2e/post-{i:02d}.png", "width": 1200, "height": 630}
                   if i % 3 == 0 else None),
        tags=[tags[i % 2]], writer=writer, **meta(i + 10)))
draft = dict(blog[7], title="Draft of post 05, unpublished")
data = {"blog": blog, "tags": tags, "writers": [writer]}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        ok = self.headers.get("X-MICROCMS-API-KEY") == key
        print(json.dumps({"host": self.headers.get("x-microcms-host"), "path": url.path, "q": q, "key": ok}), flush=True)
        if not ok:
            return self.send(401, {"message": "X-MICROCMS-API-KEY header is invalid."})
        m = re.fullmatch(r"/api/v1/([a-z]+)(?:/([^/]+))?", url.path)
        if not m or m.group(1) not in data:
            return self.send(404, {"message": "API is not found."})
        items = data[m.group(1)]
        if m.group(2):
            if m.group(1) == "blog" and m.group(2) == "post-05" and q.get("draftKey") == "e2e-draft":
                return self.send(200, draft)
            found = [x for x in items if x["id"] == m.group(2)]
            return self.send(200, found[0]) if found else self.send(404, {"message": "Content is not found."})
        if "filters" in q:
            tm = re.fullmatch(r"tags\[contains\](.+)", q["filters"])
            if not tm:
                return self.send(400, {"message": "Invalid filters."})
            items = [x for x in items if any(t["id"] == tm.group(1) for t in x.get("tags", []))]
        if q.get("q"):
            needle = q["q"].lower()
            items = [x for x in items
                     if needle in " ".join(str(x.get(f, "")) for f in ("title", "description", "content", "name")).lower()]
        offset, limit = int(q.get("offset", 0)), int(q.get("limit", 10))
        self.send(200, {"contents": items[offset:offset + limit], "totalCount": len(items),
                        "offset": offset, "limit": limit})


ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
