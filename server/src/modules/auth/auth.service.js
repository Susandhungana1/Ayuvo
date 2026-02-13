import jwt from "jsonwebtoken"
import bcrypt from "bcryptjs"
import { AuthRepository } from "./auth.repository"


export const AuthService = {

    login: async (email, password) => {
        const user = await AuthRepository.findUser(email);

        if (!user) throw new Error("User not found , please register first")

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) throw new Error("password doesnot match");

        const tokenPayload = {

            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            createdAt: user.createAt,
            updatedAt: user.updatedAt,
        }


        const token = jwt.sign(tokenPayload, env.jwt_secret, {
            expiresIn: "7d",
        });
        return { user, token }
    }




}