import React from 'react';
import { BlogCard, type BlogPost } from './blog-card';

interface BlogListProps {
  posts: BlogPost[];
}

export function BlogList({ posts }: BlogListProps) {
  if (!posts || posts.length === 0) {
    return (
      <div className="text-center py-20 bg-gray-50 rounded-2xl border border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900 mb-2">No articles found</h3>
        <p className="text-gray-500">Check back later for new updates and insights.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      {posts.map((post) => (
        <BlogCard key={post.id} post={post} />
      ))}
    </div>
  );
}
