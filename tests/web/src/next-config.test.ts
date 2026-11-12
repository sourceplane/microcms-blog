import { describe, expect, it } from "vitest";
import { createRequire } from "node:module";
import * as path from "node:path";

const require = createRequire(import.meta.url);
const config = require(path.resolve(__dirname, "../../../apps/web/next.config.js"));

describe("apps/web/next.config.js", () => {
  it("builds the standalone output OpenNext bundles, traced from the workspace root", () => {
    expect(config.output).toBe("standalone");
    expect(config.outputFileTracingRoot).toBe(path.resolve(__dirname, "../../.."));
    expect(config.images).toEqual({ unoptimized: true });
  });

  it("keeps the template's cache policy, and a draft (?dk=) is never cached — the rule its proxy.ts set", async () => {
    const rules = await config.headers();
    expect(rules).toEqual([
      {
        source: "/(.*)",
        headers: [{ key: "CDN-Cache-Control", value: "public, s-maxage=60, stale-while-revalidate=300" }],
      },
      {
        source: "/blogs/:path*",
        has: [{ type: "query", key: "dk" }],
        headers: [{ key: "CDN-Cache-Control", value: "no-store, must-revalidate" }],
      },
    ]);
  });

  it("inlines the public origin, never a microCMS value", () => {
    expect(Object.keys(config.env)).toEqual(["BASE_URL"]);
  });
});
