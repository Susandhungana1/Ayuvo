import prisma from "../../lib/prisma.js"

export const AuthRepository = {

    findUser: async (email) => {

        return await prisma.user.findUnique({
            where: { email },
        });
    }

};
