
import express from "express"
import {CreateBlog,DeleteBlog,UpdateBlog,getAllBlogs,getById} from "../../modules/blogs/blogs.controller.js"

const router=express.Router();

router.get('/')