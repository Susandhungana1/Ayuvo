import express from "express";
import {
  CreateBlog,
  DeleteBlog,
  UpdateBlog,
  getAllBlogs,
  getById,
  likeBlog,
  addComment,
} from "../../modules/blogs/blogs.controller.js";
import { authMiddleware } from "../../middleware/authMiddleware.js";
import BlogValidationSchema from "../../modules/blogs/blogs.schema.js";
import { validate } from "../../middleware/schema.validation.middleware.js";

const router = express.Router();
router.get("/", authMiddleware, getAllBlogs);
router.post("/", authMiddleware, validate(BlogValidationSchema), CreateBlog);
router.patch(
  "/:id",
  authMiddleware,
  validate(BlogValidationSchema),
  UpdateBlog,
);
router.delete("/:id", authMiddleware, DeleteBlog);
router.get("/:id", authMiddleware, getById);
router.post("/:id/like", authMiddleware, likeBlog);
router.post("/:id/comment", authMiddleware, addComment);

export default router;
