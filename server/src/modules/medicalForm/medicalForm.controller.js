import MedicalFormService from "./medicalForm.service.js";
import { BadRequestError } from "../../error/error.js";

export const addMedicalForm = async (req, res, next) => {
  try {
    const newForm = await MedicalFormService.addForm(
      req.body,
      req.user,
      req.files,
    );
    if (!newForm) throw new BadRequestError("Error Adding Medical Items");
    return res
      .status(201)
      .json({ success: true, message: "Medical form created", data: newForm });
  } catch (error) {
    next(error);
  }
};

export const updateMedicalForm = async (req, res, next) => {
  try {
    const { formId } = req.params;
    const user = req.user;
    const payload = req.body;

    const updatedForm = await MedicalFormService.updateForm(
      payload,
      user,
      formId,
    );
    if (!updatedForm) throw BadRequestError("Error Updating Medical Form");
    return res.status(200).json({
      success: true,
      message: "Medical Form Updated Successfully",
      data: updatedForm,
    });
  } catch (error) {
    next(error);
  }
};

export const deleteMedicalForm = async (req, res, next) => {
  try {
    const { id } = req.params;
    const payload = req.body;
    const user = req.user;
    const deleteItem = await MedicalFormService.deleteForm(id, user);
    if (!deleteItem) throw new BadRequestError("Error Deleting Form");
    return res.status(200).json({
      stauts: true,
      message: "form deleted successfully",
      data: deleteItem,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllMedicalForms = async (req, res, next) => {
  try {
    const user = req.user;
    const allItems = await MedicalFormService.getALLForms(user);
    if (!allItems) throw new BadRequestError("Error getting all medical forms");
    return res.status(200).json({
      success: true,
      message: "All Forms fetched Successfully",
      data: allItems,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllMedicalFormsById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = req.user;
    const item = await MedicalFormService.findItem(id, user);
    if (!item) throw new BadRequestError("Error getting item by id");
    return res.status(200).json({
      success: true,
      message: "item fetched",
      data: item,
    });
  } catch (error) {
    next(error);
  }
};
