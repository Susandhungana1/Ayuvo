import prisma from "../../lib/prisma.js";

const MedicalRepository = {
  createMedicalDocument: async (data) => {
    return await prisma.medicalDocument.create({
      data,
      include: {
        medicines: true,
        files: true,
        reports: true,
      },
    });
  },
};

export default MedicalRepository;