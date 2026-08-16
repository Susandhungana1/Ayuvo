import { Mail } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contact Us - MediStore',
  description: 'Have questions about MediStore? Reach out for help with your account, reports, or appointments.',
};

export default function Contact() {
  return (
    <div className="bg-surface min-h-screen py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h1 className="text-4xl font-display font-bold text-on-surface mb-6">Contact Us</h1>
          <p className="text-lg text-on-surface-variant">
            Have questions about MediStore? Need help setting up your account?
            Reach out and we&apos;ll get back to you as soon as possible.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-5xl mx-auto">
          {/* Email */}
          <Card className="p-xl flex flex-col items-start">
            <div className="w-12 h-12 bg-primary/10 text-primary rounded-md flex items-center justify-center mb-4">
              <Mail size={24} />
            </div>
            <h2 className="text-xl font-display font-semibold text-on-surface mb-1">Email</h2>
            <p className="text-on-surface-variant text-sm mb-4">
              Send us a message and we&apos;ll respond as soon as possible.
            </p>
            <a
              href="mailto:susandhungana20@gmail.com"
              className="text-primary hover:underline font-medium mb-6 break-all"
            >
              susandhungana20@gmail.com
            </a>
            <a href="mailto:susandhungana20@gmail.com" className="mt-auto">
              <Button>Write to us</Button>
            </a>
          </Card>

          {/* What to include */}
          <Card className="p-xl">
            <h2 className="text-xl font-display font-semibold text-on-surface mb-4">Help us help you faster</h2>
            <p className="text-on-surface-variant text-sm mb-4">
              A message with a few details gets answered in one pass instead of three:
            </p>
            <ul className="space-y-2 text-sm text-on-surface-variant">
              <li className="flex items-start gap-sm">
                <span className="w-1.5 h-1.5 rounded-full bg-primary shrink-0 mt-1.5" />
                Your user ID (the one beginning with <span className="text-on-surface font-medium tabular-nums">#hos</span>)
              </li>
              <li className="flex items-start gap-sm">
                <span className="w-1.5 h-1.5 rounded-full bg-primary shrink-0 mt-1.5" />
                The page or report the problem is about
              </li>
              <li className="flex items-start gap-sm">
                <span className="w-1.5 h-1.5 rounded-full bg-primary shrink-0 mt-1.5" />
                What you expected, and what happened instead
              </li>
            </ul>
            <p className="text-xs text-on-surface-variant mt-6">
              We reply to the address you write from. For account issues we may ask
              you to verify your email first.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}