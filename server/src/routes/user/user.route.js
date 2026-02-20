import express from "express"
import { registerUser, getAllUsers, deleteUser, updateUser, getUserBYid } from "../../modules/users/users.controller.js"
import { authMiddleware, authorizeRoles } from "../../middleware/authMiddleware.js"
import { validate } from "../../middleware/schema.validation.middleware.js"
import { updateUserSchema, createUserSchema } from "../../modules/users/user.schema.js"
const router = express.Router()


router.post('/create', validate(createUserSchema), registerUser)
router.get('/all', authMiddleware, authorizeRoles('ADMIN'), getAllUsers)
router.get('/:id', authMiddleware, getUserBYid)
router.delete('/:id', authMiddleware, deleteUser)
router.patch('/:id', authMiddleware, validate(updateUserSchema), updateUser)





export default router 