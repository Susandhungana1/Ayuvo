import Link from 'next/link';
import { Logo } from './Logo';

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-white dark:bg-[var(--color-card)] border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] mt-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-5 gap-8">
          <div className="col-span-1 md:col-span-2">
            <div className="mb-4">
              <Logo variant="full" size="sm" />
            </div>
            <p className="text-[var(--color-ink-variant)] max-w-sm">
              Your trusted digital healthcare platform. Manage your medical records securely and stay on top of your health journey.
            </p>
          </div>
          
          <div>
            <h3 className="font-semibold text-[var(--color-ink)] mb-4 tracking-wide uppercase text-sm font-heading">Quick Links</h3>
            <ul className="space-y-3">
              <li><Link href="/" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">Home</Link></li>
              <li><Link href="/about" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">About Us</Link></li>
              <li><Link href="/contact" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">Contact</Link></li>
              <li><Link href="/blog" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">Blog</Link></li>
            </ul>
          </div>

          <div>
            <h3 className="font-semibold text-[var(--color-alert)] mb-4 tracking-wide uppercase text-sm font-heading">Emergency Numbers</h3>
            <ul className="space-y-2">
              {[
                { name: 'Ambulance', num: '102' },
                { name: 'Police', num: '100' },
                { name: 'Fire Brigade', num: '101' },
                { name: 'Traffic Police', num: '103' },
                { name: 'Disaster Management', num: '1149' },
                { name: "Women's Helpline", num: '1145' },
                { name: 'Child Helpline', num: '1144' },
                { name: 'Health Emergency', num: '1115' },
              ].map((item) => (
                <li key={item.name} className="flex justify-between text-sm">
                  <span className="text-[var(--color-ink-variant)]">{item.name}</span>
                  <span className="font-bold text-[var(--color-alert)]">{item.num}</span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="font-semibold text-[var(--color-ink)] mb-4 tracking-wide uppercase text-sm font-heading">Legal</h3>
            <ul className="space-y-3">
              <li><Link href="#" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">Privacy Policy</Link></li>
              <li><Link href="#" className="text-[var(--color-ink-variant)] hover:text-[var(--color-primary)] transition-colors">Terms of Service</Link></li>
            </ul>
          </div>
        </div>
        
        <div className="border-t border-[var(--color-outline-subtle)] dark:border-[var(--color-outline)] mt-12 pt-8 flex flex-col md:flex-row justify-between items-center text-sm text-[var(--color-ink-variant)]">
          <p>&copy; {currentYear} MediStore. All rights reserved.</p>
          <div className="mt-4 md:mt-0">
            <p>susandhungana20@gmail.com | +977 9812345678</p>
          </div>
        </div>
      </div>
    </footer>
  );
}