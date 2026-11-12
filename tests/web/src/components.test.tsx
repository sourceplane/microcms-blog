import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import Article from "@/components/Article";
import ArticleList from "@/components/ArticleList";
import ConnectMicroCMS from "@/components/ConnectMicroCMS";
import Footer from "@/components/Footer";
import Header from "@/components/Header";
import Pagination from "@/components/Pagination";
import TagList from "@/components/TagList";
import { SITE_NAME } from "@/app/site";
import type { Article as ArticleData } from "@/libs/microcms";

const T = "2026-11-02T03:04:05.000Z";
const meta = { createdAt: T, updatedAt: T, publishedAt: T, revisedAt: T };
const tag = { id: "tag-1", name: "edge", ...meta };
const article = (id: string, extra: Partial<ArticleData> = {}): ArticleData => ({
  id,
  title: `Post ${id}`,
  description: `About ${id}`,
  content: '<p>Body</p><pre><code class="language-js">let n = 2;</code></pre>',
  tags: [tag],
  writer: null,
  ...meta,
  ...extra,
});
// React separates adjacent text nodes with <!-- -->; compare the text.
const html = (node: React.ReactElement) => renderToStaticMarkup(node).replace(/<!-- -->/g, "");
// …and escapes text and attributes as this does: the site's name can carry an
// apostrophe and an ampersand.
const escaped = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#x27;");

describe("the template's components, as the pages use them", () => {
  it("lists articles, each linking to its page with its tags and date", () => {
    const out = html(<ArticleList articles={[article("a1"), article("a2")]} />);
    expect(out).toContain('href="/blogs/a1"');
    expect(out).toContain('href="/blogs/a2"');
    expect(out).toContain("Post a1");
    expect(out).toContain("#edge");
    expect(out).toContain("2 November, 2026");
    // No thumbnail: the template's own placeholder image.
    expect(out).toContain("no-image.png");
  });

  it("says so when there are no articles", () => {
    expect(html(<ArticleList articles={[]} />)).toContain("Article does not exist.");
  });

  it("paginates ten to a page, keeping the search and the tag in its links", () => {
    const out = html(<Pagination totalCount={23} current={2} basePath="/search" q="edge" />);
    expect(out).toContain('href="/search/p/1?q=edge"');
    expect(out).toContain('href="/search/p/3?q=edge"');
    expect(out).not.toContain('href="/search/p/2');
    expect(out).not.toContain("/p/4");
    expect(html(<Pagination totalCount={11} basePath="/tags/tag-1" />)).toContain('href="/tags/tag-1/p/2"');
  });

  it("links each tag to its page", () => {
    expect(html(<TagList tags={[tag]} />)).toContain('href="/tags/tag-1"');
    expect(html(<TagList tags={[tag]} hasLink={false} />)).not.toContain("href=");
  });

  it("renders an article with its writer and highlighted code", () => {
    const writer = {
      id: "w1",
      name: "Ada Writer",
      image: { url: "https://images.microcms-assets.io/w.png", width: 48, height: 48 },
      ...meta,
    };
    const out = html(<Article data={article("a3", { writer })} />);
    expect(out).toContain("<h1");
    expect(out).toContain("Post a3");
    expect(out).toContain("Ada Writer");
    expect(out).toContain("https://images.microcms-assets.io/w.png?fm=webp&amp;fit=crop&amp;w=48&amp;h=48");
    expect(out).toContain('<span class="hljs-keyword">let</span>');
  });

  it("names the site in the header's logo and the footer, and links home", () => {
    const header = html(<Header />);
    expect(header).toContain(`alt="${escaped(SITE_NAME)}"`);
    expect(header).toContain('href="/"');
    expect(html(<Footer />)).toContain(`© ${escaped(SITE_NAME)}. All Rights Reserved`);
  });

  it("marks the unconnected notice and links to how to connect", () => {
    const out = html(<ConnectMicroCMS />);
    expect(out).toContain('data-microcms-notice="unconnected"');
    expect(out).toContain('href="/blogs/connect-microcms"');
  });
});
