import { getTagList, isMicroCMSConnected } from '@/libs/microcms';
import { LIMIT } from '@/constants';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import Nav from '@/components/Nav';
import ConnectMicroCMS from '@/components/ConnectMicroCMS';
import { SITE_NAME } from './site';
import './globals.css';
import styles from './layout.module.css';

export const metadata = {
  metadataBase: new URL(process.env.BASE_URL || 'http://localhost:3000'),
  title: {
    template: `%s | ${SITE_NAME}`,
    default: SITE_NAME,
  },
  description: 'A simple blog presented by microCMS',
  openGraph: {
    title: {
      template: `%s | ${SITE_NAME}`,
      default: SITE_NAME,
    },
    description: 'A simple blog presented by microCMS',
    images: '/ogp.png',
  },
  alternates: {
    canonical: '/',
  },
};

type Props = {
  children: React.ReactNode;
};

// Every page is rendered when it is requested: the microCMS service and its key
// are the Worker's, read per request (libs/microcms.ts), and a build has
// neither.
export const dynamic = 'force-dynamic';

export default async function RootLayout({ children }: Props) {
  const tags = await getTagList({
    limit: LIMIT,
  });
  return (
    <html lang="en">
      <body>
        <Header />
        <Nav tags={tags.contents} />
        <main className={styles.main}>
          {!isMicroCMSConnected() && <ConnectMicroCMS />}
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
