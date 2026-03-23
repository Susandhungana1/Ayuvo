'use client';

import React from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { MOCK_BLOG_POSTS } from '@/constants';
import { ArrowLeft, Clock, Calendar, Share2, Facebook, Twitter, Linkedin } from 'lucide-react';
import { Badge } from '@/components/badge';
import { Button } from '@/components/button';

export default function BlogDetailPage() {
  const params = useParams();
  const postId = params.id as string;
  
  const post = MOCK_BLOG_POSTS.find(p => p.id === postId);

  if (!post) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-gray-50">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Article not found</h1>
        <p className="text-gray-500 mb-6">The article you are looking for does not exist.</p>
        <Link href="/blog">
          <Button variant="outline">
            <ArrowLeft className="w-4 h-4 mr-2" /> Back to Blog
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white pb-20">
      {/* Navigation */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link href="/blog" className="inline-flex items-center text-sm font-medium text-gray-500 hover:text-blue-600 transition-colors">
          <ArrowLeft className="w-4 h-4 mr-2" /> Back to all articles
        </Link>
      </div>

      <article className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-10">
          <Badge className="bg-blue-50 text-blue-700 hover:bg-blue-100 mb-6 border border-blue-100/50 px-3 py-1 text-sm font-semibold">
            {post.category}
          </Badge>
          <h1 className="text-3xl md:text-5xl font-extrabold text-gray-900 tracking-tight leading-tight mb-6">
            {post.title}
          </h1>
          <p className="text-xl text-gray-500 leading-relaxed max-w-3xl mx-auto mb-8">
            {post.excerpt}
          </p>
          
          <div className="flex items-center justify-center gap-6 text-sm text-gray-500 font-medium">
            <div className="flex items-center">
              <Calendar className="w-4 h-4 mr-2" />
              {new Date(post.date).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
            </div>
            <div className="flex items-center">
              <Clock className="w-4 h-4 mr-2" />
              {post.readTime}
            </div>
          </div>
        </div>

        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img 
          src={post.imageUrl} 
          alt={post.title}
          className="w-full h-[400px] md:h-[500px] object-cover rounded-2xl shadow-sm mb-12"
        />

        <div className="flex flex-col md:flex-row gap-12">
          {/* Social Share Sidebar */}
          <div className="md:w-16 flex-shrink-0 flex md:flex-col items-center gap-4 py-2 border-t md:border-t-0 md:border-r border-gray-100 pr-6">
            <span className="text-xs font-semibold uppercase tracking-wider text-gray-400 md:mb-4 md:[writing-mode:vertical-lr] md:rotate-180">
              Share
            </span>
            <button className="p-2.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-full transition-all">
              <Twitter className="w-5 h-5 fill-current" />
            </button>
            <button className="p-2.5 text-gray-400 hover:text-blue-800 hover:bg-blue-50 rounded-full transition-all">
              <Facebook className="w-5 h-5 fill-current" />
            </button>
            <button className="p-2.5 text-gray-400 hover:text-blue-700 hover:bg-blue-50 rounded-full transition-all">
              <Linkedin className="w-5 h-5 fill-current" />
            </button>
            <button className="p-2.5 text-gray-400 hover:text-gray-900 hover:bg-gray-100 rounded-full transition-all mt-auto">
              <Share2 className="w-5 h-5" />
            </button>
          </div>

          {/* Article Content */}
          <div className="prose prose-lg prose-blue max-w-none flex-1 text-gray-700 prose-headings:text-gray-900 prose-a:text-blue-600 hover:prose-a:text-blue-500">
            <p className="lead text-xl text-gray-600">
              Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi tristique sapien vitae libero pellentesque, ac lacinia neque sodales. Maecenas scelerisque felis in magna vulputate, sed consequat purus dapibus.
            </p>
            
            <h2>The Science Behind the Numbers</h2>
            <p>
              Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Cras eleifend vel mi nec aliquam. Praesent a tortor ultricies, venenatis orci non, sollicitudin nisl. Suspendisse potenti. Nam varius, velit quis dictum iaculis, tellus lorem auctor justo, in ullamcorper risus diam ut dui.
            </p>
            
            <blockquote>
              "Health is not simply the absence of sickness. It's an active process of becoming aware of and making choices toward a healthy and fulfilling life."
            </blockquote>

            <h3>Key Takeaways</h3>
            <ul>
              <li>Regular checkups can help detect early markers.</li>
              <li>Don't ignore subtle changes in your baseline health.</li>
              <li>Always discuss your unique risk factors with your doctor.</li>
            </ul>

            <p>
              Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Phasellus eleifend diam ut metus congue, non dapibus metus lobortis. Integer sed mi id lacus commodo viverra.
            </p>
          </div>
        </div>
      </article>
      
      {/* Bottom CTA */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 mt-16 pt-12 border-t border-gray-100 text-center">
        <h3 className="text-2xl font-bold text-gray-900 mb-4">Ready to take control of your health?</h3>
        <p className="text-gray-600 mb-8 max-w-2xl mx-auto">
          Join thousands of patients who are already using our platform to track their medical progress securely and gain actionable insights.
        </p>
        <div className="flex justify-center gap-4">
          <Link href="/register">
            <Button size="lg" className="px-8 font-semibold shadow-sm">
              Create Free Account
            </Button>
          </Link>
          <Link href="/login">
            <Button size="lg" variant="outline" className="px-8 font-semibold">
              Sign In
            </Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
