const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  console.log("🚀 Starting Test...\n");

  //////////////////////////////////////////////////////
  // 1. CREATE USER
  //////////////////////////////////////////////////////
  const user = await prisma.user.create({
    data: {
      id: "user12345678901234567890", // 24 char
      name: "Vivek",
      email: "vivek@test.com",
      password: "123456",
    },
  });

  console.log("✅ User Created:", user);

  //////////////////////////////////////////////////////
  // 2. CREATE PROJECT
  //////////////////////////////////////////////////////
  const project = await prisma.project.create({
    data: {
      id: "proj12345678901234567890", // 24 char
      projectName: "Atlas Copco QA System",
      status: "ACTIVE",
      startDate: new Date(),
      createdBy: user.id,
    },
  });

  console.log("\n✅ Project Created:", project);

  //////////////////////////////////////////////////////
  // 3. ADD MEMBERSHIP
  //////////////////////////////////////////////////////
  const membership = await prisma.projectMembership.create({
    data: {
      userId: user.id,
      projectId: project.id,
      role: "ADMIN",
    },
  });

  console.log("\n✅ Membership Created:", membership);

  //////////////////////////////////////////////////////
  // 4. CREATE STAGE (OPTIONAL TEST)
  //////////////////////////////////////////////////////
  const stage = await prisma.stage.create({
    data: {
      id: "stage1234567890123456789",
      stageName: "Initial Inspection",
      status: "PENDING",
      projectId: project.id,
    },
  });

  console.log("\n✅ Stage Created:", stage);

  //////////////////////////////////////////////////////
  // 5. QUERY WITH RELATIONS
  //////////////////////////////////////////////////////
  const result = await prisma.project.findMany({
    include: {
      creator: true,
      memberships: {
        include: {
          user: true,
        },
      },
      stages: true,
    },
  });

  console.log("\n🔥 FINAL RESULT:");
  console.dir(result, { depth: null });
}

main()
  .catch((e) => {
    console.error("❌ Error:", e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
