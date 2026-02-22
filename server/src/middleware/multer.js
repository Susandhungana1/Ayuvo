import multer from "multer";
import path from "path";
import fs from "fs";
import { v4 as uuid } from "uuid";
import { fileURLToPath } from "url";

// Fix __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ensure directories exist
const makeDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

// create upload directories
makeDir(path.join(__dirname, "../uploads/documents"));
makeDir(path.join(__dirname, "../uploads/reports"));
makeDir(path.join(__dirname, "../uploads/medicines"));

// storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    if (file.fieldname === "files") {
      cb(null, path.join(__dirname, "../uploads/documents"));
    } else if (file.fieldname === "reports") {
      cb(null, path.join(__dirname, "../uploads/reports"));
    } else if (file.fieldname === "medicineImages") {
      cb(null, path.join(__dirname, "../uploads/medicines"));
    } else {
      cb(null, path.join(__dirname, "../uploads"));
    }
  },

  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const uniqueName = uuid() + ext;
    cb(null, uniqueName);
  },
});

// file type validation
const fileFilter = (req, file, cb) => {
  const allowedTypes = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
  ];

  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error("Unsupported file type"), false);
  }
};

// multer instance
const uploadMedical = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

export default uploadMedical;
