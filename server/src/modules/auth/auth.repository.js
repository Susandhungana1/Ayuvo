import prisma from "../../lib/prisma.js";

export const AuthRepository = {
  findUser: async (email) => {
    return await prisma.user.findFirst({
      where: { email },
      select: {
        id: true,
        password: true,
        email: true,
        role: true,
      },
    });
  },
};
