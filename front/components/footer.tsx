import Link from 'next/link';

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-white border-t border-gray-100 mt-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-5 gap-8">
          <div className="col-span-1 md:col-span-2">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <div className="w-6 h-6 bg-primary rounded flex items-center justify-center">
                <span className="text-white font-bold text-sm">+</span>
              </div>
              <span className="font-bold text-lg text-text-main tracking-tight">MediStore</span>
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
            <h3 className="font-semibold text-red-700 mb-4 tracking-wide uppercase text-sm">Emergency Numbers</h3>
            <ul className="space-y-2">
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Ambulance</span>
                <span className="font-bold text-red-700">102</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Police</span>
                <span className="font-bold text-red-700">100</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Fire Brigade</span>
                <span className="font-bold text-red-700">101</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Traffic Police</span>
                <span className="font-bold text-red-700">103</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Disaster Management</span>
                <span className="font-bold text-red-700">1149</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Women's Helpline</span>
                <span className="font-bold text-red-700">1145</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Child Helpline</span>
                <span className="font-bold text-red-700">1144</span>
              </li>
              <li className="flex justify-between text-sm">
                <span className="text-subtext">Health Emergency</span>
                <span className="font-bold text-red-700">1115</span>
              </li>
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
          <p>&copy; {currentYear} MediStore. All rights reserved.</p>
          <div className="mt-4 md:mt-0">
            <p>susandhungana20@gmail.com | +977 9812345678</p>
          </div>
        </div>
      </div>
    </footer>
  );
}
