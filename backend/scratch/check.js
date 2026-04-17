import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const models = Object.keys(prisma).filter(k => !k.startsWith('_') && !k.startsWith('$') && typeof prisma[k].count === 'function');
  const results = {};
  for (const model of models) {
    try {
      const count = await prisma[model].count();
      results[model] = count;
    } catch(err) {
      results[model] = 'ERROR: ' + err.message;
    }
  }
  console.log(JSON.stringify(results, null, 2));
}

main().catch(console.error).finally(() => prisma.$disconnect());
