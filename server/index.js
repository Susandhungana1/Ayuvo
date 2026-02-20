import express from "express";
import authRouter from "./src/routes/index.js";
import { errorHandler } from "./src/middleware/errorMiddleware.js";



const app = express();

app.use(express.json());

app.use("/v1/api", authRouter);
app.use(errorHandler);

app.get("/", (req, res) => {
  res.send("welcome");
});

app.listen(3000, () => {
  console.log("Server running on http://localhost:3000");
});
