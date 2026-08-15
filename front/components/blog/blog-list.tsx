import React from 'react';
import { BlogCard, type BlogPost } from './blog-card';

interface BlogListProps {
  posts: BlogPost[];
}

export function BlogList({ posts }: BlogListProps) {
  if (!posts || posts.length === 0) {
    return (
      <div className="text-center py-20 bg-surface-card rounded-lg border border-outline">
        <h3 className="text-lg font-display font-semibold text-on-surface mb-2">No articles found</h3>
        <p className="text-on-surface-variant">Check back later for new updates and insights.</p>
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
