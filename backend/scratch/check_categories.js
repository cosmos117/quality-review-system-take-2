import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function checkCentralizedData() {
  try {
    const categories = await prisma.globalDefectCategory.findMany();
    const settings = await prisma.globalDefectCategorySettings.findFirst();
    
    console.log('--- Centralized Defect Management Status ---');
    console.log(`Total Global Categories: ${categories.length}`);
    console.log(`Global Groups: ${settings?.defectCategoryGroups?.join(', ') || 'None'}`);
    
    if (categories.length > 0) {
      const groups = [...new Set(categories.map(c => c.group))];
      console.log(`Actual Groups in Categories: ${groups.join(', ')}`);
      console.log('\nSample Categories (Top 5):');
      categories.slice(0, 5).forEach(c => console.log(`- ${c.name} (${c.group})`));
    }
  } catch (e) {
    console.error('Error:', e);
  } finally {
    await prisma.$disconnect();
  }
}

checkCentralizedData();
