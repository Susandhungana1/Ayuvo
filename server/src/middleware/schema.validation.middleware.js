import { z } from "zod";

export const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body);

  if (!result.success) {
    // result.error is guaranteed to exist here
    const issues = result.error.issues.map((issue) => ({
      path: issue.path.join("."),
      message: issue.message,
    }));

    return res.status(400).json({ errors: issues });
  }
  // Attach validated data to request object if needed
  req.body = result.data;
  next();
};
