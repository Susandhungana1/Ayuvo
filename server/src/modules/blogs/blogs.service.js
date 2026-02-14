import { NotAuthorizedError } from "../../error/error"
import { BlogRepository } from "./blogs.repository"

export const BlogService = {
    createBlog: async (title, content, doctorId, role) => {
        const doctor = await BlogRepository.findDoctorByUserId(doctorId);
        if (!doctor && doctor.verified) throw new NotAuthorizedError('Only Verified Doctor Can Post');
        if (role !== "Doctor") throw new NotAuthorizedError('Only Doctor Can Create Blogs');

        return BlogRepository.createBlog({
            title, content, doctorId: userId
        })
    }
}