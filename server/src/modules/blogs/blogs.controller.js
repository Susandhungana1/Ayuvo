import { BadRequestError } from "../../error/error.js"
import { BlogService } from "./blogs.service.js"


export const addBlog = async (req, res, next) => {
    try {
        
        const { title, content,address,city } = req.body
        const blog = await BlogService.createBlog(title,content,address,city,req.user.id, req.user.role)

        if (!blog) throw new BadRequestError('Error Creating new Blog')

        return res.status(201).json({
            success: true,
            message: 'Blog Created Successfully',
            data: blog
        })
    } catch (error) {
        next(error)
    }
}

