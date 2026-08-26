import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Appointments - Ayuvo',
  description: 'Book appointments with doctors — coming soon to Ayuvo.',
};

export default function Appointments() {
  return <ComingSoon />;
}