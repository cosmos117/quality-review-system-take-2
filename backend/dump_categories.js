import prisma from "./src/config/prisma.js";

async function main() {
  const categories = await prisma.globalDefectCategory.findMany({
    orderBy: { name: 'asc' }
  });
  console.log(JSON.stringify(categories, null, 2));
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
