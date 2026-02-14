import { z } from "zod";

// Registration schema
export const createUserSchema = z
  .object({
    name: z.string().min(2, { message: "Name must be at least 2 characters" }),
    email: z.string().email({ message: "Invalid email format" }), // fixed
    password: z.string().min(6, { message: "Password must be at least 6 characters" }),
    role: z.enum(["PATIENT", "DOCTOR", "ADMIN"]).default("PATIENT"),
    city: z.string().min(2, { message: "City is required" }),
    address: z.string().min(5, { message: "Address is required" }),
    nmid: z.string().optional(),
    degree: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.role === "DOCTOR") {
      if (!data.nmid) ctx.addIssue({ path: ["nmid"], message: "NMID is required for doctors" });
      if (!data.degree) ctx.addIssue({ path: ["degree"], message: "Degree is required for doctors" });
    }
  });

// Update schema (all optional)
export const updateUserSchema = z
  .object({
    name: z.string().min(2).optional(),
    email: z.string().email({ message: "Invalid email format" }).optional(), // fixed
    city: z.string().min(2).optional(),
    address: z.string().min(5).optional(),
    role: z.enum(["PATIENT", "DOCTOR", "ADMIN"]).optional(),
    nmid: z.string().optional(),
    degree: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.role === "DOCTOR") {
      if (!data.nmid) ctx.addIssue({ path: ["nmid"], message: "NMID is required for doctors" });
      if (!data.degree) ctx.addIssue({ path: ["degree"], message: "Degree is required for doctors" });
    }
  });
