import Link from 'next/link';
import styles from './index.module.css';

// Shown above every page while no microCMS service is connected: the posts
// below are libs/sample.ts's, and the first of them says how to connect.
export default function ConnectMicroCMS() {
  return (
    <aside className={styles.notice} data-microcms-notice="unconnected">
      <p>
        These are sample posts: this blog is not connected to a microCMS service yet.{' '}
        <Link href="/blogs/connect-microcms" className={styles.link}>
          Connect yours
        </Link>
      </p>
    </aside>
  );
}
