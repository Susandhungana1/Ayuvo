import Link from 'next/link';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Shield, Activity, MessageSquare, Share2, UploadCloud, Clock, Lock } from 'lucide-react';

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      {/* Hero Section */}
      <section className="relative bg-white pt-20 pb-32 overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
          <div className="text-center max-w-3xl mx-auto">
            <h1 className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-text-main tracking-tight mb-6">
              Your Personal Digital <span className="text-primary">Health Tracker</span>
            </h1>
            <p className="text-lg md:text-xl text-subtext mb-10 leading-relaxed">
              Securely store, organize, and manage your medical records in one place. 
              Take control of your health journey with a trusted, digital platform designed for you.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <Link href="/auth/register">
                <Button variant="primary" className="w-full sm:w-auto text-lg px-8 py-3">
                  Get Started
                </Button>
              </Link>
              <Link href="/about">
                <Button variant="outline" className="w-full sm:w-auto text-lg px-8 py-3">
                  Learn More
                </Button>
              </Link>
            </div>
          </div>
        </div>
        
        {/* Background Decoration */}
        <div className="absolute top-0 w-full h-full overflow-hidden -z-10 bg-gradient-to-b from-blue-50/50 to-white">
          <div className="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-blue-100 blur-3xl opacity-50"></div>
          <div className="absolute top-40 -left-20 w-72 h-72 rounded-full bg-green-100 blur-3xl opacity-50"></div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-24 bg-background">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="text-3xl font-bold text-text-main mb-4">Everything You Need</h2>
            <p className="text-subtext">Comprehensive tools to manage your health efficiently and securely.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            <Card className="hover:shadow-md transition-shadow duration-300">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-6 text-primary">
                <UploadCloud size={24} />
              </div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Upload Records</h3>
              <p className="text-subtext">Easily upload and digitize your lab results, prescriptions, and medical history.</p>
            </Card>

            <Card className="hover:shadow-md transition-shadow duration-300">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-6 text-primary">
                <Activity size={24} />
              </div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Track Health</h3>
              <p className="text-subtext">Monitor your vitals and organize your appointments in an easy-to-read dashboard.</p>
            </Card>

            <Card className="hover:shadow-md transition-shadow duration-300">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-6 text-primary">
                <MessageSquare size={24} />
              </div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Chat with Doctor</h3>
              <p className="text-subtext">Communicate securely with your healthcare providers for fast and reliable advice.</p>
            </Card>

            <Card className="hover:shadow-md transition-shadow duration-300">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-6 text-primary">
                <Share2 size={24} />
              </div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Secure Sharing</h3>
              <p className="text-subtext">Share your medical records with specialists safely via encrypted links.</p>
            </Card>
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-24 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="text-3xl font-bold text-text-main mb-4">How It Works</h2>
            <p className="text-subtext">Get started with HealthTracker in three simple steps.</p>
          </div>

          <div className="flex flex-col md:flex-row justify-center items-start gap-12 max-w-5xl mx-auto">
            <div className="flex-1 text-center relative">
              <div className="w-16 h-16 bg-primary text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-6 relative z-10">1</div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Create an Account</h3>
              <p className="text-subtext">Sign up securely and verify your identity to access your personal vault.</p>
            </div>
            
            <div className="hidden md:block w-32 h-0.5 bg-gray-200 mt-8"></div>

            <div className="flex-1 text-center relative">
              <div className="w-16 h-16 bg-primary text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-6 relative z-10">2</div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Upload Documents</h3>
              <p className="text-subtext">Add your medical history, test results, and vaccination records easily.</p>
            </div>

            <div className="hidden md:block w-32 h-0.5 bg-gray-200 mt-8"></div>

            <div className="flex-1 text-center relative">
              <div className="w-16 h-16 bg-primary text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-6 relative z-10">3</div>
              <h3 className="text-xl font-semibold text-text-main mb-3">Stay Organized</h3>
              <p className="text-subtext">Access your data instantly, anywhere, and share it when necessary.</p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-primary text-white">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-6">Ready to Take Control of Your Health?</h2>
          <p className="text-blue-100 text-lg mb-10 max-w-2xl mx-auto">
            Join thousands of users who trust HealthTracker to securely manage their medical information.
          </p>
          <Link href="/auth/register">
            <Button className="bg-white text-primary hover:bg-gray-50 text-lg px-8 py-3 rounded-xl font-semibold transition-all shadow-lg hover:shadow-xl">
              Create Your Free Account
            </Button>
          </Link>
        </div>
      </section>
    </div>
  );
}
