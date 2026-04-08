import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

async function main() {
  const adminEmail = "admin@gmail.com";
  const password = "admin"; // Using "admin" as requested by user's screenshot dots (or common default)
  const hashedPassword = await bcrypt.hash(password, 10);

  // Check if admin already exists
  const existingAdmin = await prisma.user.findUnique({
    where: { email: adminEmail },
  });

  if (!existingAdmin) {
    await prisma.user.create({
      data: {
        id: "678e7c1e9e7b2a3d4f5g6h7i", // 24-char hex
        name: "Administrator",
        email: adminEmail,
        password: hashedPassword,
        role: "admin",
        status: "active",
      },
    });
    console.log("✅ Admin user created: admin@gmail.com / admin");
  } else {
    console.log("ℹ️ Admin user already exists");
  }

  // Create a default reviewer too if needed
  const reviewerEmail = "reviewer@gmail.com";
  const existingReviewer = await prisma.user.findUnique({
    where: { email: reviewerEmail },
  });

  if (!existingReviewer) {
    await prisma.user.create({
      data: {
        id: "678e7c1e9e7b2a3d4f5g6h7j",
        name: "Reviewer User",
        email: reviewerEmail,
        password: hashedPassword,
        role: "reviewer",
        status: "active",
      },
    });
    console.log("✅ Reviewer user created: reviewer@gmail.com / admin");
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
