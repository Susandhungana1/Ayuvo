import React from 'react';
import Link from 'next/link';
import { Card } from '@/components/ui/card';
import { Clock, ArrowRight } from 'lucide-react';
import { Badge } from '@/components/badge';

export interface BlogPost {
  id: string;
  title: string;
  excerpt: string;
  category: string;
  date: string;
  readTime: string;
  imageUrl: string;
  content?: string[];
}

interface BlogCardProps {
  post: BlogPost;
}

export function BlogCard({ post }: BlogCardProps) {
  return (
    <Card className="overflow-hidden group h-full flex flex-col">
      <div className="relative h-48 overflow-hidden bg-outline/20">
        {/* Using a standard img tag instead of next/image for simplicity with mock data */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={post.imageUrl}
          alt={post.title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div className="absolute top-4 left-4">
          <Badge className="bg-surface-card/95 text-primary hover:bg-surface-card backdrop-blur-sm font-semibold">
            {post.category}
          </Badge>
        </div>
      </div>
      <div className="flex flex-col flex-1 p-6">
        <div className="flex items-center text-xs text-on-surface-variant mb-3 font-medium">
          <span>{new Date(post.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <span className="mx-2">•</span>
          <div className="flex items-center">
            <Clock className="w-3.5 h-3.5 mr-1" />
            {post.readTime}
          </div>
        </div>
        <h3 className="text-xl font-display font-bold text-on-surface group-hover:text-primary transition-colors line-clamp-2 mb-3">
          {post.title}
        </h3>
        <p className="text-on-surface-variant line-clamp-3 text-sm flex-1 mb-5 leading-relaxed">
          {post.excerpt}
        </p>
        <div className="mt-auto">
          <Link
            href={`/blog/${post.id}`}
            className="inline-flex items-center text-primary font-semibold text-sm hover:text-primary-pressed transition-colors group/link"
          >
            Read Article
            <ArrowRight className="w-4 h-4 ml-1.5 group-hover/link:translate-x-1 transition-transform" />
          </Link>
        </div>
      </div>
    </Card>
  );
}