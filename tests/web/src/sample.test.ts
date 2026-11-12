import { describe, expect, it } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import { sampleClient } from "@/libs/sample";

// The sample content answers in the shapes the template's three list APIs
// define (apps/web/microcms-template.json), so every page renders it as it
// renders a connected service's.
const template = JSON.parse(
  fs.readFileSync(path.resolve(__dirname, "../../../apps/web/microcms-template.json"), "utf8"),
) as { schema: { apiEndpoint: string; apiType: string; apiFields: { fieldId: string; kind: string }[] }[] };

describe("the sample content", () => {
  it("has an item in every API the template defines, and only those fields", async () => {
    const endpoints = template.schema.map((api) => api.apiEndpoint).sort();
    expect(endpoints).toEqual(["blog", "tags", "writers"]);
    for (const api of template.schema) {
      expect(api.apiType).toBe("LIST");
      const { contents } = await sampleClient.getList<Record<string, unknown>>({ endpoint: api.apiEndpoint });
      expect(contents.length).toBeGreaterThan(0);
      const allowed = new Set([
        ...api.apiFields.map((f) => f.fieldId),
        "id",
        "createdAt",
        "updatedAt",
        "publishedAt",
        "revisedAt",
      ]);
      for (const item of contents) {
        for (const key of Object.keys(item)) expect(allowed).toContain(key);
      }
    }
  });

  it("references tags and writers that exist", async () => {
    const tags = new Set((await sampleClient.getList({ endpoint: "tags" })).contents.map((t) => t.id));
    const writers = new Set((await sampleClient.getList({ endpoint: "writers" })).contents.map((w) => w.id));
    const { contents } = await sampleClient.getList<{ tags: { id: string }[]; writer: { id: string } | null }>({
      endpoint: "blog",
    });
    for (const post of contents) {
      for (const t of post.tags) expect(tags).toContain(t.id);
      if (post.writer) expect(writers).toContain(post.writer.id);
    }
  });

  it("serves its writer's picture from the site itself", () => {
    expect(fs.existsSync(path.resolve(__dirname, "../../../apps/web/public/sample/writer.svg"))).toBe(true);
  });
});
