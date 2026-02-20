import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { AuthRepository } from "./auth.repository.js";
import { env } from "../../config/env.js";
import { BadRequestError, NotFoundError } from "../../error/error.js";

export const AuthService = {
  login: async (email, password) => {
    if (!email || !password) throw new BadRequestError("All field required");
    const user = await AuthRepository.findUser(email);
    if (!user)
      throw new NotFoundError("User not found , please register first");
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new BadRequestError("password doesnot match");
    const tokenPayload = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
    const token = jwt.sign(tokenPayload, env.jwt_secret, {
      expiresIn: "7d",
    });
    return { user, token };
  },
};
