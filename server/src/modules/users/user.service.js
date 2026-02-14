import { BadRequestError, NotFoundError } from "../../error/error.js";
import { UserRepository } from "./users.repository.js";
import bcrypt from "bcryptjs";

export const UserService = {
    createUser: async (name, email, password, role, nmid, degree, city, address) => {

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

            if (!nmid && !degree) throw new BadRequestError('NMID and Degree Required For doctor')

            return await UserRepository.registerDoctor({ name, email, password: hashedPassword, role, city, address }, { nmid, degree })
        }
        //User Creation
        return await UserRepository.registerPatient({ name, email, password: hashedPassword, role, city, address })
    },



    updateUser: async (data, id, modifierId) => {

        // ✅ Only owner can update profile
        if (modifierId !== id) {
            throw new BadRequestError("Cannot update another user's profile");
        }



        // ✅ Check if user exists
        const existingUser = await UserRepository.findUserByid(id);
        if (!existingUser) throw new NotFoundError("User not found");

        // 🔐 Prevent updating sensitive/system fields
        const forbiddenFields = [
            "password",
            "id",
            "createdAt",
            "updatedAt"
        ];
        forbiddenFields.forEach(field => delete data[field]);

        // 🚫 Prevent email change
        if (data.email) {
            throw new BadRequestError("Email cannot be changed");
        }

        // 🚫 Prevent privilege escalation
        if (data.role && ["ADMIN", "DOCTOR"].includes(data.role)) {
            throw new BadRequestError("Role change not allowed");
        }

        // 🧹 Remove undefined values
        const cleanData = Object.fromEntries(
            Object.entries(data).filter(([_, value]) => value !== undefined)
        );

        // ❌ Prevent empty update
        if (Object.keys(cleanData).length === 0) {
            throw new BadRequestError("No valid fields provided for update");
        }

        // ⚡ Optional: update only changed values
        const changedData = {};
        for (const key in cleanData) {
            if (cleanData[key] !== existingUser[key]) {
                changedData[key] = cleanData[key];
            }
        }

        if (Object.keys(changedData).length === 0) {
            throw new BadRequestError("No changes detected");
        }

        return await UserRepository.updateUser(id, changedData);
    },



    //get all users
    getAllUsers: async () => {
        return await UserRepository.getAllUsers();

    },

    //user delete
    deleteUser: async (id,modifierId) => {
          if (modifierId !== id) {
            throw new BadRequestError("Cannot update another user's profile");
        }
        const user = await UserRepository.findUserByid(id)
        if (!user) throw new BadRequestError('User doesnot Exists')

        return await UserRepository.deleteUser(id)
    },



    getByID: async (id) => {
        // const user = await UserRepository.findExistingUser(id);
        // if (!user) throw new NotFoundError('user not found with current id')
        const user = await UserRepository.findUserByid(id)
        if (!user) throw new NotFoundError('user with current id not found')
        return user
    }

}



