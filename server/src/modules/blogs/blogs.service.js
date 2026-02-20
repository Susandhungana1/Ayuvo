import {
  BadRequestError,
  NotFoundError,
  NotAuthorizedError,
} from "../../error/error.js";
import { BlogRepository } from "./blogs.repository.js";

export const BlogService = {
  create: async (payload, user) => {
    const { isEmergency, ...data } = payload;

    if (!isEmergency && user.role === "PATIENT")
      throw new BadRequestError(
        "Patient are only allowed to create Emergency Post only",
      );
    const autherId = user.id;
    return await BlogRepository.addBlog(data, autherId);
  },

  delete: async (blogId, user) => {
    const blog = await BlogRepository.getBlogByid(blogId);
    if (!blog) throw new NotFoundError("Blog Not Found");

    if (user.role === "ADMIN") {
      return await BlogRepository.deleteBlogById(blogId);
    }
    const blogCreator = blog.authorId;
    if (blogCreator !== user.id) {
      throw new NotAuthorizedError("Only creator can perform delete");
    }
    return await BlogRepository.deleteBlogById(blogId);
  },

  update: async (blogId, user, updatedBlog) => {
    const blog = await BlogRepository.getBlogByid(blogId);
    if (!blog) throw new NotFoundError("Blog Not Found");

    const { title, content, isEmergency, address, city, latitude, longitude } =
      updatedBlog;
    if (!isEmergency && user.role === "PATIENT") {
      await BlogRepository.deleteBlogById(blogId);
      return new BadRequestError("Only Emergency Post are Allowed For Users");
    }

    const data = {
      title: title,
      content: content,
      isEmergency: isEmergency,
      address: address,
      city: city,
      latitude: latitude,
      longitude: longitude,
    };

    if (user.role == "ADMIN") {
      return await BlogRepository.updateBlogByID(blogId, data);
    }
    const blogCreator = blog.authorId;

    if (blogCreator !== user.id) {
      throw new NotAuthorizedError("Only Creator Can Update");
    }
    return await BlogRepository.updateBlogByID(blogId, data);
  },
  fetchAllBlogs: async () => {
    const data = await BlogRepository.getAll();
    if (!data) {
      throw new NotFoundError("Blogs Not Found");
    }
    return data;
  },
  getBlogByid: async (id) => {
    const data = await BlogRepository.getBlogByid(id);
    return data;
  },
};
