import prisma from "./prisma.js";
import logger from "../utils/logger.js";

let databaseReady = false;

export const isDatabaseReady = () => databaseReady;

const connectDB = async () => {
  try {
    await prisma.$connect();
    databaseReady = true;
    logger.info("MySQL connected via Prisma");
    return true;
  } catch (error) {
    databaseReady = false;
    logger.error("MySQL (Prisma) connection error:", error);
    return false;
  }
};

export default connectDB;
