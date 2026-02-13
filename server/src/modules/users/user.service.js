import { BadRequestError } from "../../error/error.js";
import { UserRepository } from "./users.repository.js";
import bcrypt from "bcryptjs";

export const UserService = {
    createUser: async (name, email, password, role, nmid, degree) => {

        const userExists = await UserRepository.findExistingUser(email);
        if (userExists) throw new BadRequestError('user already exists with current email')
        if (role === "ADMIN") {
            const adminUser = await UserRepository.findAdmin();
            if (adminUser) {
                throw new BadRequestError("Only one admin is allowed");
            }
        }




        const hashedPassword = await bcrypt.hash(password, 10)
        //Doctor Creation
        if (role === "DOCTOR") {
            return await UserRepository.registerDoctor({ name, email, password: hashedPassword, role }, { nmid, degree })
        }
        //User Creation
        return await UserRepository.registerPatient({ name, email, password: hashedPassword, role })
    }
}


