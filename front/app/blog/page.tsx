"use client";

import React, { useState } from "react";
import { MOCK_BLOG_POSTS } from "@/constants";
import { BlogList } from "@/components/blog/blog-list";
import { Input } from "@/components/ui/input";
import { Search } from "lucide-react";

export default function BlogListingPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState<string>("All");

  const categories = ["All", "Education", "Technology", "Wellness", "News"];

  const filteredPosts = MOCK_BLOG_POSTS.filter((post) => {
    const matchesSearch =
      post.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      post.excerpt.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory =
      activeCategory === "All" || post.category === activeCategory;
    return matchesSearch && matchesCategory;
  });

  return (
    <div className="min-h-screen bg-surface">
      {/* Hero */}
      <section className="bg-surface-card border-b border-outline pt-16 pb-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <span className="inline-flex items-center rounded-sm bg-primary/10 text-primary px-3 py-1 text-xs font-semibold mb-4">
            Latest Insights
          </span>
          <h1 className="text-4xl md:text-5xl font-display font-bold text-on-surface tracking-tight mb-6">
            Health & Wellness Hub
          </h1>
          <p className="text-xl text-on-surface-variant max-w-2xl mx-auto leading-relaxed">
            Practical advice, technology trends, and clinical insights
            to empower your health journey.
          </p>
        </div>
      </section>

      {/* Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-10">
          <div className="flex flex-wrap items-center gap-2">
            {categories.map((category) => {
              const active = activeCategory === category;
              return (
                <button
                  key={category}
                  onClick={() => setActiveCategory(category)}
                  className={`px-4 py-1.5 rounded-sm text-sm font-medium border transition-colors ${
                    active
                      ? "bg-primary text-on-primary border-primary"
                      : "bg-surface-card text-on-surface-variant border-outline hover:border-primary/50 hover:text-on-surface"
                  }`}
                >
                  {category}
                </button>
              );
            })}
          </div>

          <div className="w-full md:w-80 relative">
            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
              <Search className="h-4 w-4 text-on-surface-variant" />
            </div>
            <Input
              type="text"
              placeholder="Search articles..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        <BlogList posts={filteredPosts} />
      </main>
    </div>
  );
}