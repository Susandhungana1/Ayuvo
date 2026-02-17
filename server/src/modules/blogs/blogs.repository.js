import prisma from "../../lib/prisma.js";

export const BlogRepository = {
  addBlog: async (blog) => {
    const blog = {
      title: blog.title,
      content: blog.content,
      published: blog.published,
      authorId: blog.id, ///check uid
      isEmergency: blog.isEmergency,
      address: blog.address,
      city: blog.city,
      latitude: blog.latitude,
      longitude: blog.longitude,
      createdAt: blog.createdAt,
      updatedAt: blog.createdAt,
    };

    return await prisma.blog.create({
      data: blog,
    });
  },

  getBlogByid: async (id) => {
    return await prisma.blog.findFirst({ where: { id: id } });
  },

  DeleteBlogById: async (id) => {
    return await prisma.blog.delete(id);
  },
  UpdateBlog: async (data, id) => {
    return await prisma.blog.update({ where: id, data: data });
  },
  getAll: async () => {
    return await prisma.blog.findMany();
  },
};
