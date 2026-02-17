import { BadRequestError, NotFoundError } from "../../error/error.js";
import { BlogService } from "./blogs.service.js";

export const CreateBlog = async (req, res, next) => {
  try {
    const payload = req.body;
    const item = await BlogService.Create(payload);
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
    const deleteBlog = await BlogService.Delete(user, id);
    if (!deleteBlog) throw new BadRequestError("Error Deleting Blog");
    return res.status(200).json({
      success: true,
      message: "User Deleted Successfully",
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

    const blog = await BlogService.Update(id, user, req.body);
    if (!blog) throw new BadRequestError("Blog Not Found");
    return res
      .status(200)
      .json({ success: true, message: "blog updated successfully" });
  } catch (error) {
    next(error);
  }
};

export const getAllBlogs = async (req, res, next) => {
  try {
    const blogs = await BlogService.FetchAllBlogs();
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
