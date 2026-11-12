import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// What libs/microcms.ts promises: the service and its key are read on every
// call, from the Worker's env when there is a Cloudflare context and from the
// process otherwise; without both, every read is answered from the sample
// content and microCMS is never called; with both, the template's own SDK
// calls are made, and a refused read is a 404 page.

const ENV = ["MICROCMS_SERVICE_DOMAIN", "MICROCMS_API_KEY"] as const;
// Where @opennextjs/cloudflare's getCloudflareContext() finds the Worker's
// context while a request is being served.
const CONTEXT = Symbol.for("__cloudflare-context__");
const saved: Record<string, string | undefined> = {};

beforeEach(() => {
  for (const k of ENV) {
    saved[k] = process.env[k];
    delete process.env[k];
  }
  vi.resetModules();
});
afterEach(() => {
  for (const k of ENV) {
    if (saved[k] === undefined) delete process.env[k];
    else process.env[k] = saved[k];
  }
  delete (globalThis as Record<symbol, unknown>)[CONTEXT];
  vi.unstubAllGlobals();
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

// next/navigation's notFound() throws an error Next turns into the 404 page.
const isNotFound = (e: unknown) => String((e as { digest?: string }).digest ?? "").includes("404");

describe("unconnected (no service, no key)", () => {
  it("needs both values — one alone is not a connection", async () => {
    const m = await import("@/libs/microcms");
    expect(m.isMicroCMSConnected()).toBe(false);
    process.env.MICROCMS_SERVICE_DOMAIN = "my-blog";
    expect(m.isMicroCMSConnected()).toBe(false);
    process.env.MICROCMS_API_KEY = "  ";
    expect(m.isMicroCMSConnected()).toBe(false);
    process.env.MICROCMS_API_KEY = "key";
    expect(m.isMicroCMSConnected()).toBe(true);
  });

  it("answers every read from the sample content and never calls microCMS", async () => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const m = await import("@/libs/microcms");
    const list = await m.getList({ limit: 10 });
    expect(list.contents.map((a) => a.id)).toEqual([
      "connect-microcms",
      "rendered-on-workers",
      "drafts-tags-and-search",
    ]);
    expect(list.totalCount).toBe(3);
    const dates = list.contents.map((a) => Date.parse(a.publishedAt ?? a.createdAt));
    expect([...dates].sort((a, b) => b - a)).toEqual(dates);
    expect((await m.getList({ limit: 2, offset: 2 })).contents.map((a) => a.id)).toEqual([
      "drafts-tags-and-search",
    ]);
    const tagged = await m.getList({ limit: 10, filters: "tags[contains]getting-started" });
    expect(tagged.contents.map((a) => a.id)).toEqual(["connect-microcms", "drafts-tags-and-search"]);
    expect((await m.getList({ q: "HIGHLIGHT.JS" })).contents.map((a) => a.id)).toEqual([
      "rendered-on-workers",
    ]);
    const post = await m.getDetail("rendered-on-workers", { draftKey: "ignored" });
    expect(post.title).toBe("Rendered on Cloudflare Workers");
    expect(post.writer?.name).toBe("Sample Writer");
    expect((await m.getTagList({ limit: 10 })).contents.map((t) => t.name)).toEqual([
      "getting-started",
      "cloudflare",
    ]);
    expect((await m.getTag("cloudflare")).name).toBe("cloudflare");
    expect(fetch).not.toHaveBeenCalled();
  });

  it("is a 404 for a post, a tag or a filter it does not have", async () => {
    const m = await import("@/libs/microcms");
    for (const read of [
      () => m.getDetail("no-such-post"),
      () => m.getTag("no-such-tag"),
      () => m.getList({ filters: "title[equals]x" }),
    ]) {
      const e = await read().then(
        () => null,
        (err: unknown) => err,
      );
      expect(e && isNotFound(e)).toBe(true);
    }
  });

  it("tells the first post how to connect: the two secrets and the template's APIs", async () => {
    const m = await import("@/libs/microcms");
    const post = await m.getDetail("connect-microcms");
    for (const words of [
      "MICROCMS_SERVICE_DOMAIN",
      "MICROCMS_API_KEY",
      "microcms-template.json",
      "<code>tags</code>",
      "<code>writers</code>",
      "<code>blog</code>",
    ]) {
      expect(post.content).toContain(words);
    }
  });
});

describe("connected", () => {
  it("calls the service's content API with the key, per request, as the template's SDK does", async () => {
    const fetch = vi.fn(async () => json({ contents: [], totalCount: 0, offset: 0, limit: 10 }));
    vi.stubGlobal("fetch", fetch);
    process.env.MICROCMS_SERVICE_DOMAIN = "my-blog";
    process.env.MICROCMS_API_KEY = "key-1";
    const m = await import("@/libs/microcms");
    await m.getList({ limit: 10, filters: "tags[contains]t1" });
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://my-blog.microcms.io/api/v1/blog?limit=10&filters=tags%5Bcontains%5Dt1");
    expect(new Headers(init.headers).get("X-MICROCMS-API-KEY")).toBe("key-1");
    // A key changed after the module loaded is the one the next read uses.
    process.env.MICROCMS_API_KEY = "key-2";
    await m.getTagList({ limit: 10 });
    const [url2, init2] = fetch.mock.calls[1] as unknown as [string, RequestInit];
    expect(url2).toBe("https://my-blog.microcms.io/api/v1/tags?limit=10");
    expect(new Headers(init2.headers).get("X-MICROCMS-API-KEY")).toBe("key-2");
  });

  it("reads the Worker's env first, over anything in the process", async () => {
    const fetch = vi.fn(async () => json({ id: "p1", title: "From the Worker's service", tags: [], writer: null }));
    vi.stubGlobal("fetch", fetch);
    process.env.MICROCMS_SERVICE_DOMAIN = "process-blog";
    process.env.MICROCMS_API_KEY = "process-key";
    (globalThis as Record<symbol, unknown>)[CONTEXT] = {
      env: { MICROCMS_SERVICE_DOMAIN: "worker-blog", MICROCMS_API_KEY: "worker-key" },
      ctx: {},
      cf: {},
    };
    const m = await import("@/libs/microcms");
    const post = await m.getDetail("p1", { draftKey: "dk1" });
    expect(post.title).toBe("From the Worker's service");
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://worker-blog.microcms.io/api/v1/blog/p1?draftKey=dk1");
    expect(new Headers(init.headers).get("X-MICROCMS-API-KEY")).toBe("worker-key");
  });

  it("shows the samples when the Worker has no service, whatever the process holds", async () => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    process.env.MICROCMS_SERVICE_DOMAIN = "process-blog";
    process.env.MICROCMS_API_KEY = "process-key";
    (globalThis as Record<symbol, unknown>)[CONTEXT] = { env: {}, ctx: {}, cf: {} };
    const m = await import("@/libs/microcms");
    expect(m.isMicroCMSConnected()).toBe(false);
    expect((await m.getList()).totalCount).toBe(3);
    expect(fetch).not.toHaveBeenCalled();
  });

  it("turns a refused read into the 404 page, as upstream does", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => json({ message: "Content is not found." }, 404)));
    process.env.MICROCMS_SERVICE_DOMAIN = "my-blog";
    process.env.MICROCMS_API_KEY = "key";
    const m = await import("@/libs/microcms");
    const e = await m.getDetail("gone").then(
      () => null,
      (err: unknown) => err,
    );
    expect(e && isNotFound(e)).toBe(true);
  });
});
