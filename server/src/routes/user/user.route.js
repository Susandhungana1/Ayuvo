import express from "express"
import { registerUser } from "../../modules/users/users.controller.js"
const router = express.Router()

router.post('/create', registerUser)

export default router