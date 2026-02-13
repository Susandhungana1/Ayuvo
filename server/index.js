import express from "express";
import authRouter from "./routes/authRoute.js";

const app = express();

app.use(express.json());


app.use('/auth', authRouter);

app.listen(3000, () => {
  console.log("Server running on http://localhost:3000");
});
