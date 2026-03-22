import MedicalRepository from "./medicalFormrepository.js";
import OCRService from "../../lib/ocr.service.js";

const MedicalFormService = {
  addForm: async (formData, user, files) => {
    // Extract text from reports if any
    let extractedReports = [];
    if (files?.reports) {
      extractedReports = await Promise.all(
        files.reports.map(async (file, index) => {
          const extractedText = await OCRService.extractText(file.path);
          return {
            fileUrl: file.path,
            userId: user.id,
            reportType: formData.reportTypes
              ? JSON.parse(formData.reportTypes)[index]
              : "OTHERS", // changed from "OTHER" to "OTHERS" to match MedicalReportType enum
            reportDate: formData.reportDates
              ? new Date(JSON.parse(formData.reportDates)[index])
              : null,
            notes: formData.reportNotes
              ? JSON.parse(formData.reportNotes)[index]
              : null,
            extractedText: extractedText || null,
          };
        }),
      );
    }

    // Prepare data for Prisma
    const documentData = {
      // associate user via userId
      userId: user.id,
      hospital: formData.hospital,
      location: formData.location,
      doctorName: formData.doctorName,
      department: formData.department,
      description: formData.description,
      checkupDate: formData.checkupDate
        ? new Date(formData.checkupDate)
        : undefined,

      // medicines nested create
      medicines: formData.medicines
        ? {
            create: JSON.parse(formData.medicines).map((item, index) => {
              // formData.medicines is likely an array of strings representing medicine names
              // or it could be a JSON string of objects if the frontend sends it that way.
              // The original code was JSON.parse(formData.medicines).map((name, index) => ...
              return {
                name: typeof item === "string" ? item : item.name,
                imageUrl: files?.medicineImages?.[index]?.path || null,
              };
            }),
          }
        : undefined,

      // doctor files nested create
      files: files?.files
        ? {
            create: files.files.map((file) => ({
              name: file.originalname,
              url: file.path,
              fileType: "DOCTOR_TICKET", // must match FileType enum
            })),
          }
        : undefined,

      // reports nested create
      reports: extractedReports.length > 0
        ? {
            create: extractedReports,
          }
        : undefined,
    };

    // call repository
    const newDocument = await MedicalRepository.createMedicalDocument(documentData);
    return newDocument;
  },
};

export default MedicalFormService;