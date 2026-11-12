import { describe, expect, it } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";

const web = path.resolve(__dirname, "../../../apps/web");

describe("site identity (apps/web/app/site.ts)", () => {
  it("names the blog", async () => {
    const { SITE_NAME } = await import("@/app/site");
    expect(SITE_NAME.trim()).not.toBe("");
  });

  it("keeps the template's MIT licence and credit", () => {
    const licence = fs.readFileSync(path.join(web, "LICENSE"), "utf8");
    expect(licence).toContain("MIT License");
    expect(licence).toContain("Copyright (c) 2023 microCMS");
  });
});
