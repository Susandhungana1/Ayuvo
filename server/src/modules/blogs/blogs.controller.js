import { BadRequestError, NotFoundError } from "../../error/error.js";
import { BlogService } from "./blogs.service.js";

export const CreateBlog = async (req, res, next) => {
  try {
    const payload = req.body;
    const user = req.user;
    const item = await BlogService.create(payload, user);
    if (!item) throw BadRequestError("Error Creating New Blog");
    return res.status(201).json({
      success: true,
      message: "Blog Created Successfully",
      data: item,
    });
  } catch (error) {
    next(error);
  }
};

export const DeleteBlog = async (req, res, next) => {
  try {
    const { id } = req.params; //blog id

    const user = req.user;
    const deleteBlog = await BlogService.delete(id, user);
    if (!deleteBlog) throw new BadRequestError("Error Deleting Blog");
    return res.status(200).json({
      success: true,
      message: "Blog Deleted Successfully",
      data: deleteBlog,
    });
  } catch (error) {
    next(error);
  }
};

export const UpdateBlog = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = req.user;
    const blog = await BlogService.update(id, user, req.body);
    if (!blog) throw new BadRequestError("Blog Not Found");
    return res.status(200).json({
      success: true,
      message: "blog updated successfully",
      data: blog,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllBlogs = async (req, res, next) => {
  try {
    const blogs = await BlogService.fetchAllBlogs();
    if (!blogs) throw new BadRequestError("No Blogs Found");

    return res
      .status(200)
      .json({ success: true, message: "All blogs fetched", data: blogs });
  } catch (error) {
    next(error);
  }
};

export const getById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const blog = await BlogService.getBlogByid(id);
    if (!blog) throw new NotFoundError("Blog Not Found");
    return res
      .status(200)
      .json({ message: "blog fetched", success: true, data: blog });
  } catch (error) {
    next(error);
  }
};

export const likeBlog = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = req.user;
    const result = await BlogService.likeBlog(id, user);
    return res.status(200).json({
      success: true,
      message: result.message,
    });
  } catch (error) {
    next(error);
  }
};

export const addComment = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = req.user;
    const { content, parentId } = req.body;
    const result = await BlogService.addComment(id, user, content, parentId);
    return res.status(201).json({
      success: true,
      message: "Comment added successfully",
      data: result[0],
    });
  } catch (error) {
    next(error);
  }
};
