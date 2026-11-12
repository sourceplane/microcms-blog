import { describe, expect, it } from "vitest";
import { formatDate, formatRichText } from "@/libs/utils";

// The template's rich-text rendering, unchanged: code blocks are highlighted on
// the server with highlight.js (by their language class, or detected), and the
// rest of microCMS's HTML is kept as written.
describe("formatRichText", () => {
  it("highlights a code block in the language its class names", () => {
    const html = formatRichText('<p>Hi</p><pre><code class="language-ts">const a: number = 1;</code></pre>');
    expect(html).toContain("<p>Hi</p>");
    expect(html).toContain('<span class="hljs-keyword">const</span>');
    expect(html).toContain('<span class="hljs-number">1</span>');
  });

  it("detects the language when the block names none, and survives one it does not know", () => {
    expect(formatRichText("<pre><code>def f(x):\n    return x</code></pre>")).toContain("hljs-");
    expect(formatRichText('<pre><code class="language-nope">let x = 1</code></pre>')).toContain("hljs-");
  });

  it("leaves HTML outside code blocks alone, entities included", () => {
    const html = formatRichText('<h2 id="a">Tom &amp; Jerry</h2><p><a href="/x">x</a></p>');
    expect(html).toBe('<h2 id="a">Tom &amp; Jerry</h2><p><a href="/x">x</a></p>');
  });
});

describe("formatDate", () => {
  it("writes the date in Tokyo time, as the template does", () => {
    expect(formatDate("2026-11-11T15:30:00.000Z")).toBe("12 November, 2026");
    expect(formatDate("2026-11-11T14:00:00.000Z")).toBe("11 November, 2026");
  });
});
