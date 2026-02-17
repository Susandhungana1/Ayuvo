import jwt from "jsonwebtoken";
import { AuthRepository } from "../modules/auth/auth.repository.js";
import { NotAuthorizedError, NotFoundError } from '../error/error.js'
export const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization token missing" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // decoded contains userId
    const email = decoded.email
    console.log(`decoded token`, decoded);

    const user = await AuthRepository.findUser(email);
    if (!user) throw new NotFoundError('User not found')
    next();
  } catch (err) {
    return res.status(401).json({ message: "Token expired or invalid" });
  }
};


export const authorizeRoles = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      throw new NotAuthorizedError('Not Authorize')
    }
    next();
  };
};


