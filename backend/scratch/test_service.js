import { PrismaClient } from '@prisma/client';
import * as defectService from '../src/services/defect-category.service.js';

async function testService() {
  try {
    console.log('Fetching global settings...');
    const settings = await defectService.getGlobalDefectSettings();
    console.log('Settings:', settings);

    console.log('Fetching global categories (this might trigger seeding)...');
    const categories = await defectService.getGlobalDefectCategories();
    console.log('Total Categories:', categories.length);
    
    if (categories.length > 0) {
      console.log('Sample:', categories[0].name);
    }
  } catch (e) {
    console.error('Service Error:', e);
  }
}

testService();
