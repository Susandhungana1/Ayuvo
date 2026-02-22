import express from "express";
const router = express.Router();
import { authMiddleware } from "../../middleware/authMiddleware.js";
import { addMedicalForm } from "../../modules/medicalForm/medicalForm.controller.js";
import uploadMedical from "../../middleware/multer.js";
router.use(authMiddleware);

router.post(
  "/",
  uploadMedical.fields([
    { name: "files", maxCount: 10 },
    { name: "reports", maxCount: 10 },
    { name: "medicineImages", maxCount: 10 },
  ]),
  addMedicalForm,
);
export default router;
