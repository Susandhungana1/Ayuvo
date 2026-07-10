import { Button } from '@/components/button';
import { Input } from '@/components/input';
import { Card } from '@/components/card';
import { Mail } from 'lucide-react';

export default function Contact() {
  return (
    <div className="bg-background min-h-screen py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h1 className="text-4xl font-extrabold text-text-main mb-6">Contact Us</h1>
          <p className="text-lg text-subtext">
            Have questions about MediStore? Need help setting up your account? 
            Reach out and I'll get back to you as soon as possible.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 max-w-5xl mx-auto">
          {/* Contact Information */}
          <div className="space-y-8">
            <h2 className="text-2xl font-bold text-text-main mb-6">Get in Touch</h2>
            
            <Card className="flex items-start gap-4 p-6">
              <div className="w-12 h-12 bg-blue-50 text-primary rounded-lg flex items-center justify-center flex-shrink-0">
                <Mail size={24} />
              </div>
              <div>
                <h3 className="font-semibold text-text-main mb-1">Email</h3>
                <p className="text-subtext mb-2">Send me an email and I'll respond as soon as possible.</p>
                <a href="mailto:susandhungana20@gmail.com" className="text-primary hover:underline font-medium">
                  susandhungana20@gmail.com
                </a>
              </div>
            </Card>
          </div>

          {/* Contact Form */}
          <Card className="p-8">
            <h2 className="text-2xl font-bold text-text-main mb-6">Send a Message</h2>
            <form className="space-y-6">
              <Input 
                label="Full Name" 
                placeholder="John Doe" 
                required 
              />
              <Input 
                label="Email Address" 
                type="email" 
                placeholder="john@example.com" 
                required 
              />
              
              <div className="w-full flex flex-col gap-1.5">
                <label className="text-sm font-medium text-text-main">
                  Message
                </label>
                <textarea 
                  className="w-full px-4 py-2.5 rounded-lg border border-gray-300 bg-white text-text-main placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent transition-all duration-200 min-h-[120px] resize-y"
                  placeholder="How can we help you?"
                  required
                ></textarea>
              </div>

              <Button type="button" variant="primary" className="w-full py-3">
                Send Message
              </Button>
            </form>
          </Card>
        </div>
      </div>
    </div>
  );
}