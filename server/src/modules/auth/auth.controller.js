import { AuthService } from "./auth.service"


export const loginUser = async (req, res) => {
    try {
        const { email, password } = req.body

        const user = await AuthService.login(email, password)
        if (!user) throw new Error('login failled')

        return res.status(200).json({
            success: true,
            message: "User logged in successfully",
            data: {
                id: user.user.id,
                email: user.user.email,
            },
            token: user.token,
        });
    } catch (error) {
        return res.status(500).json({
            success: false,
            message: "Something went wrong. Internal Server Error",
            error: err.message,
        });

    }
}






