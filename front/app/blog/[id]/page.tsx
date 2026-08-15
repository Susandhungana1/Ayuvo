'use client';

import React from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { MOCK_BLOG_POSTS } from '@/constants';
import { ArrowLeft, Clock, Calendar } from 'lucide-react';
import { Badge } from '@/components/badge';
import { Button } from '@/components/ui/button';

export default function BlogDetailPage() {
  const params = useParams();
  const postId = params.id as string;

  const post = MOCK_BLOG_POSTS.find(p => p.id === postId);

  if (!post) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-surface">
        <h1 className="text-2xl font-display font-bold text-on-surface mb-2">Article not found</h1>
        <p className="text-on-surface-variant mb-6">The article you are looking for does not exist.</p>
        <Link href="/blog">
          <Button variant="secondary">
            <ArrowLeft className="w-4 h-4 mr-2" /> Back to Blog
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface pb-20">
      {/* Navigation */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link href="/blog" className="inline-flex items-center text-sm font-medium text-on-surface-variant hover:text-primary transition-colors">
          <ArrowLeft className="w-4 h-4 mr-2" /> Back to all articles
        </Link>
      </div>

      <article className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-10">
          <Badge className="bg-primary/10 text-primary hover:bg-primary/15 mb-6 px-3 py-1 text-sm font-semibold">
            {post.category}
          </Badge>
          <h1 className="text-3xl md:text-5xl font-display font-bold text-on-surface tracking-tight leading-tight mb-6">
            {post.title}
          </h1>
          <p className="text-xl text-on-surface-variant leading-relaxed max-w-3xl mx-auto mb-8">
            {post.excerpt}
          </p>

          <div className="flex items-center justify-center gap-6 text-sm text-on-surface-variant font-medium">
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
          className="w-full h-[400px] md:h-[500px] object-cover rounded-lg border border-outline mb-12"
        />

        <div className="max-w-3xl mx-auto space-y-6">
          {(post.content ?? []).map((paragraph, i) => (
            <p key={i} className="text-on-surface-variant leading-relaxed text-lg">
              {paragraph}
            </p>
          ))}
        </div>
      </article>

      {/* Bottom CTA */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 mt-16 pt-12 border-t border-outline text-center">
        <h3 className="text-2xl font-display font-bold text-on-surface mb-4">Put your own records to work</h3>
        <p className="text-on-surface-variant mb-8 max-w-2xl mx-auto">
          MediStore reads your lab reports, draws the reference band under every
          value, and keeps your medicines, vitals and appointments in one place.
        </p>
        <div className="flex justify-center gap-4">
          <Link href="/auth/register">
            <Button>Create Free Account</Button>
          </Link>
          <Link href="/auth/login">
            <Button variant="secondary">Sign In</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}