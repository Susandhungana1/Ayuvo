"use client";

import React, { useState } from "react";
import Link from "next/link";
import { MOCK_BLOG_POSTS } from "@/constants";
import { BlogList } from "@/components/blog/blog-list";
import { Input } from "@/components/input";
import { Badge } from "@/components/badge";
import { Search, HeartPulse } from "lucide-react";

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
    <div className="min-h-screen bg-white">
      {/* Hero Section */}
      <section className="bg-gradient-to-b from-blue-50/50 to-white pt-16 pb-12 border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100 px-3 py-1 mb-4">
            Latest Insights
          </Badge>
          <h1 className="text-4xl md:text-5xl font-extrabold text-gray-900 tracking-tight mb-6">
            Health & Wellness Hub
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto leading-relaxed">
            Discover actionable advice, technology trends, and clinical insights
            to empower your health journey.
          </p>
        </div>
      </section>

      {/* Content Section */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-10">
          <div className="flex flex-wrap items-center gap-2">
            {categories.map((category) => (
              <Badge
                key={category}
                variant={activeCategory === category ? "default" : "outline"}
                className={`cursor-pointer px-4 py-1.5 text-sm transition-all duration-200 ${
                  activeCategory === category
                    ? "bg-blue-600 text-white hover:bg-blue-700 border-blue-600 shadow-sm"
                    : "bg-white text-gray-600 hover:bg-gray-50 border-gray-200"
                }`}
                onClick={() => setActiveCategory(category)}
              >
                {category}
              </Badge>
            ))}
          </div>

          <div className="w-full md:w-80 relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Search className="h-4 w-4 text-gray-400" />
            </div>
            <Input
              type="text"
              placeholder="Search articles..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10 bg-gray-50/50 border-gray-200 focus-visible:ring-blue-500 rounded-full h-11"
            />
          </div>
        </div>

        <BlogList posts={filteredPosts} />
      </main>
    </div>
  );
}
