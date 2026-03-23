import Link from 'next/link';

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-white border-t border-gray-100 mt-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="col-span-1 md:col-span-2">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <div className="w-6 h-6 bg-primary rounded flex items-center justify-center">
                <span className="text-white font-bold text-sm">+</span>
              </div>
              <span className="font-bold text-lg text-text-main tracking-tight">HealthTracker</span>
            </Link>
            <p className="text-subtext max-w-sm">
              Your trusted digital healthcare platform. Manage your medical records securely and stay on top of your health journey.
            </p>
          </div>
          
          <div>
            <h3 className="font-semibold text-text-main mb-4 tracking-wide uppercase text-sm">Quick Links</h3>
            <ul className="space-y-3">
              <li><Link href="/" className="text-subtext hover:text-primary transition-colors">Home</Link></li>
              <li><Link href="/about" className="text-subtext hover:text-primary transition-colors">About Us</Link></li>
              <li><Link href="/contact" className="text-subtext hover:text-primary transition-colors">Contact</Link></li>
              <li><Link href="/blog" className="text-subtext hover:text-primary transition-colors">Blog</Link></li>
            </ul>
          </div>

          <div>
            <h3 className="font-semibold text-text-main mb-4 tracking-wide uppercase text-sm">Legal</h3>
            <ul className="space-y-3">
              <li><Link href="#" className="text-subtext hover:text-primary transition-colors">Privacy Policy</Link></li>
              <li><Link href="#" className="text-subtext hover:text-primary transition-colors">Terms of Service</Link></li>
            </ul>
          </div>
        </div>
        
        <div className="border-t border-gray-100 mt-12 pt-8 flex flex-col md:flex-row justify-between items-center text-sm text-subtext">
          <p>&copy; {currentYear} HealthTracker. All rights reserved.</p>
          <div className="mt-4 md:mt-0">
            <p>support@healthtracker.com | +1 (555) 123-4567</p>
          </div>
        </div>
      </div>
    </footer>
  );
}
