import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'My Availability - Ayuvo',
  description: 'Set your availability for patient bookings — coming soon to Ayuvo.',
};

export default function DoctorAvailability() {
  return <ComingSoon />;
}