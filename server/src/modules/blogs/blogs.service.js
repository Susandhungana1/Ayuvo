import {
  BadRequestError,
  NotFoundError,
  NotAuthorizedError,
} from "../../error/error";
import { BlogRepository } from "./blogs.repository";

export const BlogService = {
  Create: async (payload) => {
    const { role, isEmergency, ...data } = payload;
    if (isEmergency && role === "PATIENT")
      throw new BadRequestError(
        "Patient are only allowed to create Emergency Post only",
      );
    return BlogRepository.addBlog(data);
  },

  Delete: async (blogId, user) => {
    const blog = await BlogRepository.getBlogByid(blogId);
    //blog exists or not
    if (!blog) throw new NotFoundError("Blog Not Found");

    if (user.role === "ADMIN") {
      return await BlogRepository.DeleteBlogById(blogId);
      //delete blog
    }
    const blogCreator = blog.authorId;
    if (blogCreator !== user.id) {
      throw new NotAuthorizedError("Only creator can perform delete");
    }
    return await BlogRepository.DeleteBlogById(blogId);
  },

  Update: async (blogId, user, updatedBlog) => {
    const blog = await BlogRepository.getBlogByid(blogId);
    if (!blog) throw new NotFoundError("Blog Not Found");

    const { title, content, isEmergency, address, city, latitude, longitude } =
      updatedBlog;
    if (!isEmergency && user.role === "PATIENT") {
      await BlogRepository.DeleteBlogById(blogId);
      return BadRequestError("Only Emergency Post are Allowed For Users");
    }

    const data = {
      title,
      content,
      isEmergency,
      address,
      city,
      latitude,
      longitude,
    };

    if (user.role == "ADMIN") {
      return await BlogRepository.UpdateBlog(id, data);
    }
    const blogCreator = blog.authorId;

    if (blogCreator !== user.id) {
      throw new NotAuthorizedError("Only Creator Can Update");
    }
    return await BlogRepository.UpdateBlog(id, data);
  },

  FetchAllBlogs: async () => {
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
