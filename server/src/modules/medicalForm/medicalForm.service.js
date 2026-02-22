import MedicalRepository from "./medicalFormrepository.js";

const MedicalFormService = {
  addForm: async (formData, user, files) => {
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
            create: JSON.parse(formData.medicines).map((name, index) => ({
              name,
              imageUrl: files?.medicineImages?.[index]?.path || null,
            })),
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
      reports: files?.reports
        ? {
            create: files.reports.map((file, index) => ({
              fileUrl: file.path,
               userId: user.id,
              reportType: formData.reportTypes
                ? JSON.parse(formData.reportTypes)[index]
                : "OTHER", // must match MedicalReportType enum
              reportDate: formData.reportDates
                ? new Date(JSON.parse(formData.reportDates)[index])
                : null,
              notes: formData.reportNotes
                ? JSON.parse(formData.reportNotes)[index]
                : null,
            })),
          }
        : undefined,
    };

    // call repository
    const newDocument = await MedicalRepository.createMedicalDocument(documentData);
    return newDocument;
  },
};

export default MedicalFormService;