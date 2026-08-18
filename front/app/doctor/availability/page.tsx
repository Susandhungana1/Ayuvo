import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'My Availability - MediStore',
  description: 'Set your availability for patient bookings — coming soon to MediStore.',
};

export default function DoctorAvailability() {
  return <ComingSoon />;
}