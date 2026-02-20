import { z } from "zod";

const BlogValidationSchema = z.object({
  id: z.string().uuid(), // Ensure it's a valid UUID
  title: z.string().min(1, "Title is required"), // Title should not be empty
  content: z.string().min(1, "Content is required"), // Content should not be empty
  published: z.boolean().default(true), // Published is a boolean with a default value of true
  authorId: z.string(),
  isEmergency: z.boolean().default(false), // Emergency flag
  address: z.string().optional(), // Address is optional
  city: z.string().optional(), // City is optional
  latitude: z.number().optional(), // Latitude is optional and should be a number
  longitude: z.number().optional(), // Longitude is optional and should be a number
  likeCount: z.number().int().nonnegative().default(0), // Like count should be a non-negative integer
  commentCount: z.number().int().nonnegative().default(0), // Comment count should be a non-negative integer
  shareCount: z.number().int().nonnegative().default(0), // Share count should be a non-negative integer
  createdAt: z.date().default(() => new Date()), // Created date defaults to the current date
  updatedAt: z.date().default(() => new Date()), // Updated date defaults to the current date
  deletedAt: z.date().optional(), // Deleted date is optional
});
export default BlogValidationSchema;
