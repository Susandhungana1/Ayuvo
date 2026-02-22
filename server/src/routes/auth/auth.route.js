import express from "express";
const router = express.Router();
import { loginUser } from "../../modules/auth/auth.controller.js";

router.post("/login", loginUser);

export default router;
