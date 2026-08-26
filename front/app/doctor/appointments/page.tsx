import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Patient Appointments - Ayuvo',
  description: 'Review and manage patient appointments — coming soon to Ayuvo.',
};

export default function DoctorAppointments() {
  return <ComingSoon />;
}