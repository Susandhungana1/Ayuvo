import { BadRequestError } from "../../error/error.js";
import { UserService } from "./user.service.js";

export const registerUser = async (req, res, next) => {
  try {
    const { name, email, password, role, nmid, degree, city, address } =
      req.body;

    const user = await UserService.createUser(
      name,
      email,
      password,
      role,
      nmid,
      degree,
      city,
      address,
    );

    return res.status(201).json({
      success: true,
      message: "User registered successfully",
      data: user,
    });
  } catch (error) {
    next(error);
  }
};

export const updateUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const modifierId = req.user.id;
    const data = req.body;
    const modifierRole = req.user.role;

    const updatedUser = await UserService.updateUser(
      data,
      id,
      modifierId,
      modifierRole,
    );

    return res.status(200).json({
      success: true,
      message: "User updated successfully",
      data: updatedUser,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllUsers = async (req, res, next) => {
  try {
    const users = await UserService.getAllUsers();
    if (!users) throw new BadRequestError("Users Not Found");

    return res
      .status(200)
      .json({
        success: true,
        message: "user fetched successfullly",
        data: users,
      });
  } catch (error) {
    next(error);
  }
};

export const deleteUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { password } = req.body;
    const deletedUser = await UserService.deleteUser(id, req.user, password);
    if (!deletedUser) throw new BadRequestError("Error deleting User");
    return res
      .status(200)
      .json({
        success: true,
        message: "user deleted successfully",
        data: deletedUser,
      });
  } catch (error) {
    next(error);
  }
};

export const getUserBYid = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = await UserService.getByID(req.user, id);
    if (!user) throw new BadRequestError("Error getting user By id");
    return res
      .status(200)
      .json({ success: true, message: "user fetched by id", data: user });
  } catch (error) {
    next(error);
  }
};
