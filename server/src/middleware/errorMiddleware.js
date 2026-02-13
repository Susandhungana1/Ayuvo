import { AppError } from "../error/error.js";

export const errorHandler = (err, req, res, next) => {
	// checking if err is the instance of our custom error type
	console.log(err);
	
	if (err instanceof AppError) {
		return res.status(err.statusCode).json({
			success: false,
			error: err.message,
		});
	}

	return res.status(500).json({
		success: false,
		error: "Internal Server Error",
		message: err.message,
	});
};
