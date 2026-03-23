import React from 'react';
import Link from 'next/link';
import { Card, CardContent } from '@/components/ui/card';
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
}

interface BlogCardProps {
  post: BlogPost;
}

export function BlogCard({ post }: BlogCardProps) {
  return (
    <Card className="overflow-hidden group h-full flex flex-col border-gray-200 hover:shadow-lg transition-all duration-300">
      <div className="relative h-48 overflow-hidden bg-gray-100">
        {/* Using a standard img tag instead of next/image for simplicity with mock data */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img 
          src={post.imageUrl} 
          alt={post.title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
        />
        <div className="absolute top-4 left-4">
          <Badge className="bg-white/90 text-blue-700 hover:bg-white backdrop-blur-sm border-0 font-semibold shadow-sm">
            {post.category}
          </Badge>
        </div>
      </div>
      <CardContent className="flex flex-col flex-1 p-6">
        <div className="flex items-center text-xs text-gray-500 mb-3 font-medium">
          <span>{new Date(post.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          <span className="mx-2">•</span>
          <div className="flex items-center">
            <Clock className="w-3.5 h-3.5 mr-1" />
            {post.readTime}
          </div>
        </div>
        <h3 className="text-xl font-bold text-gray-900 group-hover:text-blue-600 transition-colors line-clamp-2 mb-3">
          {post.title}
        </h3>
        <p className="text-gray-600 line-clamp-3 text-sm flex-1 mb-5 leading-relaxed">
          {post.excerpt}
        </p>
        <div className="mt-auto">
          <Link 
            href={`/blog/${post.id}`}
            className="inline-flex items-center text-blue-600 font-semibold text-sm hover:text-blue-700 transition-colors group/link"
          >
            Read Article
            <ArrowRight className="w-4 h-4 ml-1.5 group-hover/link:translate-x-1 transition-transform" />
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}
