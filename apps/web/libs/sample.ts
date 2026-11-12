import type {
  GetListDetailRequest,
  GetListRequest,
  MicroCMSListContent,
  MicroCMSListResponse,
} from 'microcms-js-sdk';
import type { BlogClient } from './microcms';

// What the blog shows before a microCMS service is connected: three sample
// posts, two tags and a writer, in the shapes the template's three list APIs
// answer (microcms-template.json: blog, tags, writers). libs/microcms.ts hands
// this client to every page until MICROCMS_SERVICE_DOMAIN and
// MICROCMS_API_KEY reach the Worker; the layout then says the blog is not
// connected. Nothing here calls microCMS.

const date = (iso: string) => ({
  createdAt: iso,
  updatedAt: iso,
  publishedAt: iso,
  revisedAt: iso,
});

const gettingStarted = {
  id: 'getting-started',
  name: 'getting-started',
  ...date('2026-11-10T00:00:00.000Z'),
};
const cloudflare = { id: 'cloudflare', name: 'cloudflare', ...date('2026-11-10T00:00:00.000Z') };
const tags = [gettingStarted, cloudflare];

const writer = {
  id: 'sample-writer',
  name: 'Sample Writer',
  profile: 'A writer from the sample content. Yours come from the writers API.',
  image: { url: '/sample/writer.svg', width: 96, height: 96 },
  ...date('2026-11-10T00:00:00.000Z'),
};

const blog = [
  {
    id: 'connect-microcms',
    title: 'Connect your microCMS service',
    description:
      'This blog is showing sample posts. Create a microCMS service, add its three APIs and store two secrets, and it shows yours.',
    content: [
      '<p>Every post on this blog is a sample: no microCMS service is connected yet. Four steps make it read yours.</p>',
      '<h2 id="create">1. Create a service</h2>',
      '<p>Sign up at <a href="https://app.microcms.io/signup">microCMS</a> (the free Hobby plan is enough) and create a service with <strong>Create your own</strong>.</p>',
      '<h2 id="apis">2. Add the three list APIs</h2>',
      '<p>The blog reads three APIs, all in the <strong>list</strong> format: <code>tags</code> (a <code>name</code>), <code>writers</code> (<code>name</code>, <code>profile</code>, <code>image</code>) and <code>blog</code> (<code>title</code>, <code>description</code>, <code>content</code>, <code>thumbnail</code>, <code>tags</code>, <code>writer</code>). <code>apps/web/microcms-template.json</code> describes them, and the README walks through each field. Write a tag, a writer and a post, and publish them.</p>',
      '<h2 id="secrets">3. Store the service and its key</h2>',
      "<p>The service ID (the <code>xxxx</code> in <code>https://xxxx.microcms.io</code>) and the <strong>default</strong> API key from <strong>API keys</strong> are this product's secrets, per environment:</p>",
      '<pre><code class="language-bash">orun secrets set MICROCMS_SERVICE_DOMAIN --env stage   # prompts for the value\norun secrets set MICROCMS_API_KEY        --env stage\norun secrets set MICROCMS_SERVICE_DOMAIN --env prod\norun secrets set MICROCMS_API_KEY        --env prod</code></pre>',
      '<h2 id="deploy">4. Redeploy</h2>',
      '<p>The deploy pushes both to the Worker as secrets, and every page reads them when it renders. The next deploy shows your posts, and this notice is gone.</p>',
    ].join(''),
    tags: [gettingStarted],
    writer,
    ...date('2026-11-12T00:00:00.000Z'),
  },
  {
    id: 'rendered-on-workers',
    title: 'Rendered on Cloudflare Workers',
    description:
      'Every page is rendered by one Worker when it is requested, reading microCMS with a key the Worker holds.',
    content: [
      '<p>This blog is Next.js built by OpenNext into one Cloudflare Worker with its static files beside it. Each page is rendered when it is requested, so a post published in microCMS shows on the next visit, with no rebuild.</p>',
      '<p>The service and its API key never reach a build or a browser: the Worker reads them per request and creates the microCMS client then.</p>',
      '<pre><code class="language-ts">export const client = (): BlogClient =&gt; {\n  const { MICROCMS_SERVICE_DOMAIN, MICROCMS_API_KEY } = getCloudflareContext().env;\n  if (!MICROCMS_SERVICE_DOMAIN || !MICROCMS_API_KEY) return sampleClient;\n  return createClient({ serviceDomain: MICROCMS_SERVICE_DOMAIN, apiKey: MICROCMS_API_KEY });\n};</code></pre>',
      '<p>Code blocks in a post are highlighted on the server with highlight.js, as the template does.</p>',
    ].join(''),
    tags: [cloudflare],
    writer,
    ...date('2026-11-11T00:00:00.000Z'),
  },
  {
    id: 'drafts-tags-and-search',
    title: 'Drafts, tags and search',
    description:
      'Preview a draft with its draft key, list posts by tag, and search the whole blog.',
    content: [
      "<p>The template's features all work on Workers:</p>",
      "<ul><li><strong>Drafts</strong>: microCMS's preview opens <code>/blogs/&lt;id&gt;?dk=&lt;draft key&gt;</code>, which reads the draft and is never cached.</li>",
      '<li><strong>Tags</strong>: <code>/tags/&lt;id&gt;</code> lists the posts that carry a tag.</li>',
      "<li><strong>Search</strong>: the search box asks microCMS's full-text search, <code>/search?q=…</code>.</li>",
      '<li><strong>Pages</strong>: ten posts a page, at <code>/p/2</code> and on.</li></ul>',
    ].join(''),
    tags: [gettingStarted],
    writer,
    ...date('2026-11-10T00:00:00.000Z'),
  },
];

const apis: Record<string, MicroCMSListContent[]> = { blog, tags, writers: [writer] };

const text = (item: Record<string, unknown>) =>
  ['title', 'description', 'content', 'name']
    .map((key) => (typeof item[key] === 'string' ? (item[key] as string) : ''))
    .join(' ')
    .replace(/<[^>]+>/g, ' ')
    .toLowerCase();

// The SDK's error for a missing API or content, which the pages turn into a 404.
const notFoundError = (endpoint: string, contentId?: string) =>
  Object.assign(new Error('fetch API response status: 404'), {
    status: 404,
    url: `sample:/api/v1/${endpoint}${contentId ? `/${contentId}` : ''}`,
  });

export const sampleClient: BlogClient = {
  getList: async <T = unknown>({ endpoint, queries = {} }: GetListRequest) => {
    let contents = apis[endpoint];
    if (!contents) throw notFoundError(endpoint);
    const tag = queries.filters?.match(/^tags\[contains\](.+)$/)?.[1];
    if (queries.filters && tag === undefined) throw notFoundError(endpoint);
    if (tag !== undefined) {
      contents = contents.filter((item) =>
        ((item as { tags?: { id: string }[] }).tags ?? []).some((t) => t.id === tag),
      );
    }
    const q = queries.q?.trim().toLowerCase();
    if (q)
      contents = contents.filter((item) =>
        text(item as unknown as Record<string, unknown>).includes(q),
      );
    const offset = queries.offset ?? 0;
    const limit = queries.limit ?? 10;
    return {
      contents: contents.slice(offset, offset + limit),
      totalCount: contents.length,
      offset,
      limit,
    } as unknown as MicroCMSListResponse<T>;
  },
  getListDetail: async <T = unknown>({ endpoint, contentId }: GetListDetailRequest) => {
    const found = apis[endpoint]?.find((item) => item.id === contentId);
    if (!found) throw notFoundError(endpoint, contentId);
    return found as unknown as T & MicroCMSListContent;
  },
};
