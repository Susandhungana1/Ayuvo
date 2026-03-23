import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import Link from 'next/link';

export default function Login() {
  return (
    <div className="bg-background min-h-[calc(100vh-64px)] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">
        
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="w-12 h-12 bg-primary rounded-xl flex items-center justify-center">
              <span className="text-white font-bold text-3xl">+</span>
            </div>
          </div>
          <h2 className="text-3xl font-extrabold text-text-main mb-2">Welcome Back</h2>
          <p className="text-subtext text-sm">
            Sign in to access your digital health vault
          </p>
        </div>

        <Card className="p-8 shadow-sm">
          <form className="space-y-6">
            <Input 
              label="Email Address"
              type="email"
              placeholder="you@example.com"
              required
            />
            
            <div className="space-y-1">
              <Input 
                label="Password"
                type="password"
                placeholder="••••••••"
                required
              />
              <div className="flex justify-end pt-1">
                <Link href="#" className="text-sm font-medium text-primary hover:text-blue-700 transition-colors">
                  Forgot password?
                </Link>
              </div>
            </div>

            <Button type="button" className="w-full py-3">
              Sign In
            </Button>
          </form>

          <div className="mt-8 relative">
            <div className="absolute inset-0 flex items-center" aria-hidden="true">
              <div className="w-full border-t border-gray-200"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-2 bg-white text-gray-500">Or</span>
            </div>
          </div>

          <div className="mt-8 text-center text-sm text-subtext">
            Don't have an account?{' '}
            <Link href="/auth/register" className="font-medium text-primary hover:text-blue-700 transition-colors">
              Create one now
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}
