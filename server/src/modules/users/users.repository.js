import prisma from "../../lib/prisma.js";

export const UserRepository = {
  findExistingUser: async (email) => {
    return await prisma.user.findUnique({ where: { email } });
  },

  //Register Users

  registerPatient: async (userData) => {
    return await prisma.user.create({
      data: userData,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        city: true,
        address: true,
        createdAt: true,
        updatedAt: true,
      },
    });
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
        city: true,
        address: true,
        createdAt: true,
        doctor: {
          select: {
            id: true,
            nmid: true,
            degree: true,
            verified: true,
          },
        },
      },
    });
  },

  ///GET USERS
  getAllUsers: async () => {
    return await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        city: true,
        address: true,
        createdAt: true,
        doctor: {
          select: {
            nmid: true,
            degree: true,
            verified: true,
          },
        },
      },
    });
  },

  //Find User By Id
  findUserByid: async (id) => {
    return await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        city: true,
        address: true,
        doctor: {
          select: {
            nmid: true,
            degree: true,
            verified: true,
          },
        },
      },
    });
  },

  ///Update User
  updateUser: async (id, data) => {
    return await prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        city: true,
        address: true,
        doctor: {
          select: {
            nmid: true,
            degree: true,
            verified: true,
          },
        },
      },
    });
  },

  deleteUser: async (id) => {
    return await prisma.user.delete({
      where: { id },
      select: { id: true },
    });
  },

  ////////////Check Admin
  findAdmin: async () => {
    return await prisma.user.findFirst({
      where: { role: "ADMIN" },
    });
  },
};
