import jwt from "jsonwebtoken";
import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { setDatabaseReady } from "../config/db.js";

const isPrismaConnectionError = (error) => {
  if (!error) return false;

  return (
    error.code === "P1001" ||
    error.code === "P1002" ||
    error.code === "P1008" ||
    error.code === "P1017" ||
    /can't reach database server|can't connect to database server/i.test(
      error.message || "",
    )
  );
};

const authMiddleware = async (req, _, next) => {
  try {
    const token =
      req.cookies?.token || req.header("Authorization")?.replace("Bearer ", "");
    if (!token) throw new ApiError(401, "Not authenticated");

    const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);

    // In Mongoose token payload was probably { _id: "..." }
    const userId = decoded?._id || decoded?.id;

    if (!userId) throw new ApiError(401, "Invalid token payload");

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        accessToken: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user || user.accessToken !== token)
      throw new ApiError(401, "Session expired, please log in again");

    // Remove accessToken from the req.user object for security
    const { accessToken, ...userWithoutToken } = user;
    // ensure _id is present for backward compatibility with Mongoose code
    userWithoutToken._id = userWithoutToken.id;

    req.user = userWithoutToken;
    next();
  } catch (error) {
    if (isPrismaConnectionError(error)) {
      setDatabaseReady(false);
      return next(
        new ApiError(
          503,
          "Database connection is unavailable. Start MySQL or update DATABASE_URL, then retry.",
        ),
      );
    }

    if (
      error.name === "JsonWebTokenError" ||
      error.name === "TokenExpiredError" ||
      error instanceof jwt.JsonWebTokenError
    ) {
      return next(new ApiError(401, "Session expired, please log in again"));
    }
    next(error);
  }
};

export default authMiddleware;
