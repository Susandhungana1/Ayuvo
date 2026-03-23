import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import Link from 'next/link';

export default function Register() {
  return (
    <div className="bg-background min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">
        
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="w-12 h-12 bg-primary rounded-xl flex items-center justify-center">
              <span className="text-white font-bold text-3xl">+</span>
            </div>
          </div>
          <h2 className="text-3xl font-extrabold text-text-main mb-2">Create an Account</h2>
          <p className="text-subtext text-sm">
            Join HealthTracker to securely manage your medical records
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          <form className="space-y-5">
            <Input 
              label="Full Name"
              type="text"
              placeholder="John Doe"
              required
            />
            
            <Input 
              label="Email Address"
              type="email"
              placeholder="you@example.com"
              required
            />
            
            <Input 
              label="Password"
              type="password"
              placeholder="Create a strong password"
              required
            />

            <Input 
              label="Confirm Password"
              type="password"
              placeholder="Confirm your password"
              required
            />

            <div className="pt-2">
              <Button type="button" className="w-full py-3">
                Register
              </Button>
            </div>
            
            <p className="text-xs text-subtext text-center mt-4">
              By registering, you agree to our{' '}
              <a href="#" className="text-primary hover:underline">Terms of Service</a> and{' '}
              <a href="#" className="text-primary hover:underline">Privacy Policy</a>.
            </p>
          </form>

          <div className="mt-6 text-center text-sm text-subtext border-t border-gray-100 pt-6">
            Already have an account?{' '}
            <Link href="/auth/login" className="font-medium text-primary hover:text-blue-700 transition-colors">
              Sign in
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}
