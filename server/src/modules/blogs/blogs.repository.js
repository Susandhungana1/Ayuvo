import prisma from "../../lib/prisma.js";

export const BlogRepository = {
  addBlog: async (blog, authorId) => {
    const item = {
      title: blog.title,
      content: blog.content,
      published: blog.published,
      authorId: authorId, ///check uid
      isEmergency: blog.isEmergency,
      address: blog.address,
      city: blog.city,
      latitude: blog.latitude,
      longitude: blog.longitude,
      createdAt: blog.createdAt,
      updatedAt: blog.createdAt,
    };
    return await prisma.blog.create({
      data: item,
    });
  },
  getBlogByid: async (id) => {
    return await prisma.blog.findUnique({ where: { id: id } });
  },
  deleteBlogById: async (id) => {
    return await prisma.blog.delete({ where: { id: id } });
  },
  updateBlogByID: async (id, blog) => {
    return await prisma.blog.update({
      where: {
        id: id,
      },
      data: blog,
      select: {
        title: true,
      },
    });
  },
  getAll: async () => {
    return await prisma.blog.findMany();
  },
  likeBlog: async (blogId, userId) => {
    const existingLike = await prisma.blogLike.findUnique({
      where: { blogId_userId: { blogId, userId } },
    });

    if (existingLike) {
      await prisma.$transaction([
        prisma.blogLike.delete({ where: { id: existingLike.id } }),
        prisma.blog.update({
          where: { id: blogId },
          data: { likeCount: { decrement: 1 } },
        }),
      ]);
      return { message: "Blog unliked successfully" };
    } else {
      await prisma.$transaction([
        prisma.blogLike.create({ data: { blogId, userId } }),
        prisma.blog.update({
          where: { id: blogId },
          data: { likeCount: { increment: 1 } },
        }),
      ]);
      return { message: "Blog liked successfully" };
    }
  },
  addComment: async (blogId, userId, content, parentId = null) => {
    return await prisma.$transaction([
      prisma.comment.create({
        data: {
          content,
          blogId,
          userId,
          parentId,
        },
      }),
      prisma.blog.update({
        where: { id: blogId },
        data: { commentCount: { increment: 1 } },
      }),
    ]);
  },
};
