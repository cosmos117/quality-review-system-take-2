import jwt from "jsonwebtoken";
import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";

const authMiddleware = async (req, _, next) => {
  try {
    const token = req.cookies?.token || req.header("Authorization")?.replace("Bearer ","");
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
          updatedAt: true
      }
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
    next(error);
  }
};

export default authMiddleware;
