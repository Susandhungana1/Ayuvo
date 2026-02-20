import express from "express";
import {
  CreateBlog,
  DeleteBlog,
  UpdateBlog,
  getAllBlogs,
  getById,
} from "../../modules/blogs/blogs.controller.js";
import { authMiddleware } from "../../middleware/authMiddleware.js";

const router = express.Router();

router.get("/", authMiddleware, getAllBlogs);
router.post("/", authMiddleware, CreateBlog);
router.patch("/:id", authMiddleware, UpdateBlog);
router.delete("/:id", authMiddleware, DeleteBlog);
router.get("/:id", authMiddleware, getById);

export default router;
