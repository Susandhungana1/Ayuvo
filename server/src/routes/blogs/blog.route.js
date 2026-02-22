import express from "express";
import {
  CreateBlog,
  DeleteBlog,
  UpdateBlog,
  getAllBlogs,
  getById,
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

export default router;
