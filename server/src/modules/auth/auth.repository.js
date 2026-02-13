import prisma from "../../lib/prisma"

export const AuthRepository = {

    findUser: async (email) => {

        return await prisma.user.findUnique({
            where: { email },
        });
    }

};
