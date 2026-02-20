import express from "express";
const v1Router = express.Router();
import authRouter from "./auth/auth.route.js";
import userRouter from "./user/user.route.js";
import blogRouter from "./blogs/blog.route.js";

v1Router.use("/auth", authRouter);
v1Router.use("/user", userRouter);
v1Router.use("/blog", blogRouter);

export default v1Router;
