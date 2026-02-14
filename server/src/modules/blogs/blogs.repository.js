import prisma from "../../lib/prisma.js"


export const BlogRepository = {


    createBlog: async (data) => {
        return await prisma.blog.create(data)

    },

    findDoctorByUserId: async (userId) => {
        return await prisma.user.findUnique({ where: { userId } })



    }





}