import { BadRequestError } from "../../error/error.js"
import { UserService } from "./user.service.js"

export const registerUser = async (req, res, next) => {

    try {
        const { name, email, password, role, nmid, degree } = req.body
        if (role === "DOCTOR") {
            if (!nmid || !degree) {
                throw new BadRequestError('nmid and degreee  are required for doctor')
            }
        }
           
        const user = await UserService.createUser(name, email, password, role, nmid, degree)

        if (user) {
            return res.status(201).json({
                success: true,
                message: 'user register successfully',
                data: user
            })
        }

    } catch (error) {
        next(error)

    }
}