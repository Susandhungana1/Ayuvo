import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Appointments - MediStore',
  description: 'Book appointments with doctors — coming soon to MediStore.',
};

export default function Appointments() {
  return <ComingSoon />;
}