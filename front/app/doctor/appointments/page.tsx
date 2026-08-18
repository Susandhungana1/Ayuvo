import { ComingSoon } from '@/components/coming-soon';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Patient Appointments - MediStore',
  description: 'Review and manage patient appointments — coming soon to MediStore.',
};

export default function DoctorAppointments() {
  return <ComingSoon />;
}