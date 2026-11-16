import express, { type Express, type NextFunction, type Request, type Response } from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import router from "./routes";

const app: Express = express();

app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);
app.use(cookieParser());
// Body parsing is handled by the Cloudflare Workers adapter (worker-adapter.ts)

app.use("/api", router);

// Error-handling middleware (Express 5 catches async handler errors automatically)
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error("Unhandled error:", err.message, err.stack);
  res.status(500).json({ success: false, message: "Internal server error" });
});

export default app;
