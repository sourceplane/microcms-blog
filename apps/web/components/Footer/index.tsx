import { SITE_NAME } from '@/app/site';
import styles from './index.module.css';

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <p className={styles.cr}>© {SITE_NAME}. All Rights Reserved 2023</p>
    </footer>
  );
}
