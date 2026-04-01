import prisma from "./prisma.js";
import logger from "../utils/logger.js";

const connectDB = async () => {
  try {
    await prisma.$connect();
    logger.info("MySQL connected via Prisma");
  } catch (error) {
    logger.error("MySQL (Prisma) connection error:", error);
    process.exit(1);
  }
};

export default connectDB;