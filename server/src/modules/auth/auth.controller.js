import { BadRequestError } from "../../error/error.js";
import { AuthService } from "./auth.service.js";

export const loginUser = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await AuthService.login(email, password);
    if (!user) throw new BadRequestError("login failled");

    return res.status(200).json({
      success: true,
      message: "User logged in successfully",
      data: {
        id: user.user.id,
        email: user.user.email,
        role: user.user.role,
      },
      token: user.token,
    });
  } catch (error) {
    next(error);
  }
};
