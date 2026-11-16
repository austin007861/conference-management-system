import { Router, type IRouter } from "express";
import healthRouter from "./health";
import conferenceRouter from "./conference";
import authRouter from "./auth";

const router: IRouter = Router();

router.use(authRouter);
router.use(healthRouter);
router.use(conferenceRouter);

export default router;
