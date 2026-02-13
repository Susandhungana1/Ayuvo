import prisma from "../../lib/prisma.js"



export const UserRepository = {

    findExistingUser: async (email) => {
        return await prisma.user.findUnique({ where: { email } })

    },

    registerPatient: async (userData) => {
        return await prisma.user.create({
            data: userData,
            select: {
                id: true,
                name: true,
                email: true,
                role: true,
                createdAt: true,
                updatedAt: true
            }
        })
    },



    registerDoctor: async (userData, doctorData) => {
        return await prisma.user.create({
            data: {
                ...userData,
                doctor: {
                    create: doctorData,
                },
            },
            select: {
                id: true,
                name: true,
                email: true,
                role: true,
                createdAt: true,
                doctor: {
                    select: {
                        id: true,
                        nmid: true,
                        degree: true,
                        verified: true
                    }
                }
            }
        });
    },
    findAdmin: async () => {
        return await prisma.user.findFirst({
            where: { role: "ADMIN" },
        });
    },





}