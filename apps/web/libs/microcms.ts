import { createClient } from 'microcms-js-sdk';
import type {
  MicroCMSQueries,
  MicroCMSImage,
  MicroCMSDate,
  MicroCMSContentId,
} from 'microcms-js-sdk';
import { notFound } from 'next/navigation';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import { sampleClient } from './sample';

export type Tag = {
  name?: string;
} & MicroCMSContentId &
  MicroCMSDate;

export type Writer = {
  name?: string;
  profile?: string;
  image?: MicroCMSImage;
} & MicroCMSContentId &
  MicroCMSDate;

export type Blog = {
  title?: string;
  description?: string;
  content?: string;
  thumbnail?: MicroCMSImage;
  tags: Tag[];
  writer: Writer | null;
};

export type Article = Blog & MicroCMSContentId & MicroCMSDate;

// The calls the blog makes, which the SDK's client and the sample client
// (libs/sample.ts) both answer.
export type BlogClient = Pick<ReturnType<typeof createClient>, 'getList' | 'getListDetail'>;

type Vars = Partial<Record<'MICROCMS_SERVICE_DOMAIN' | 'MICROCMS_API_KEY', string>>;

// The service and its API key, read from the Worker on every request: the
// product's Orun secrets, which the deploy pushes to the Worker as secrets
// (tooling/wire/worker-secrets.mjs) and no build ever sees. Without a
// Cloudflare context (`next dev`, the tests) they are environment variables,
// as upstream read them.
function vars(): Vars {
  try {
    return getCloudflareContext().env as Vars;
  } catch {
    return process.env as Vars;
  }
}

// Whether a microCMS service is connected. Upstream threw at module load
// without both values, so a fresh deploy answered every page with a 500; here
// the blog renders its sample posts (libs/sample.ts) and says so.
export const isMicroCMSConnected = () => {
  const v = vars();
  return Boolean(v.MICROCMS_SERVICE_DOMAIN?.trim() && v.MICROCMS_API_KEY?.trim());
};

// Initialize Client SDK, per request: the keys can change with a deploy, and
// a Worker isolate outlives one.
export const client = (): BlogClient => {
  const v = vars();
  const serviceDomain = v.MICROCMS_SERVICE_DOMAIN?.trim();
  const apiKey = v.MICROCMS_API_KEY?.trim();
  if (!serviceDomain || !apiKey) {
    return sampleClient;
  }
  return createClient({
    serviceDomain,
    apiKey,
  });
};

// get blog list
export const getList = async (queries?: MicroCMSQueries) => {
  const listData = await client()
    .getList<Blog>({
      endpoint: 'blog',
      queries,
    })
    .catch(notFound);
  return listData;
};

// get blog detail
export const getDetail = async (contentId: string, queries?: MicroCMSQueries) => {
  const detailData = await client()
    .getListDetail<Blog>({
      endpoint: 'blog',
      contentId,
      queries,
    })
    .catch(notFound);

  return detailData;
};

// get tag list
export const getTagList = async (queries?: MicroCMSQueries) => {
  const listData = await client()
    .getList<Tag>({
      endpoint: 'tags',
      queries,
    })
    .catch(notFound);

  return listData;
};

// get tag detail
export const getTag = async (contentId: string, queries?: MicroCMSQueries) => {
  const detailData = await client()
    .getListDetail<Tag>({
      endpoint: 'tags',
      contentId,
      queries,
    })
    .catch(notFound);

  return detailData;
};
