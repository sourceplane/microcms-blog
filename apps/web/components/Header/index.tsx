import Image from 'next/image';
import Link from 'next/link';
import { SITE_NAME } from '@/app/site';
import styles from './index.module.css';

export default function Header() {
  return (
    <header className={styles.header}>
      <Link href="/">
        <Image
          src="/logo.svg"
          alt={SITE_NAME}
          className={styles.logo}
          width={348}
          height={133}
          priority
        />
      </Link>
    </header>
  );
}
