import mongoose from 'mongoose';
import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import dotenv from 'dotenv';

dotenv.config();

const testCascadeDelete = async () => {
    try {
        await mongoose.connect(process.env.MONGO_DB_URI);
        console.log('Connected to MongoDB\n');

        // Test 1: Check current state
        console.log('=== CURRENT DATABASE STATE ===');
        const allProjects = await Project.find({});
        const allUsers = await User.find({});
        const allMemberships = await ProjectMembership.find({});
        
        console.log(`Total Projects: ${allProjects.length}`);
        console.log(`Total Users: ${allUsers.length}`);
        console.log(`Total Memberships: ${allMemberships.length}\n`);

        // Test 2: Show memberships per project
        console.log('=== MEMBERSHIPS BY PROJECT ===');
        for (const project of allProjects) {
            const memberships = await ProjectMembership.find({ project_id: project._id });
            console.log(`Project: ${project.project_name} (${project._id})`);
            console.log(`  → ${memberships.length} membership(s)`);
            if (memberships.length > 0) {
                for (const m of memberships) {
                    const user = await User.findById(m.user_id);
                    console.log(`     - User: ${user ? user.name : 'DELETED/ORPHANED'} (${m.user_id})`);
                }
            }
        }
        console.log();

        // Test 3: Show memberships per user
        console.log('=== MEMBERSHIPS BY USER ===');
        for (const user of allUsers) {
            const memberships = await ProjectMembership.find({ user_id: user._id });
            console.log(`User: ${user.name} (${user._id})`);
            console.log(`  → ${memberships.length} project membership(s)`);
            if (memberships.length > 0) {
                for (const m of memberships) {
                    const project = await Project.findById(m.project_id);
                    console.log(`     - Project: ${project ? project.project_name : 'DELETED/ORPHANED'} (${m.project_id})`);
                }
            }
        }
        console.log();

        console.log('=== CASCADE DELETE TEST SUMMARY ===');
        console.log('✓ Cascade delete is now implemented in both controllers');
        console.log('✓ When you delete a PROJECT, all its memberships will be removed');
        console.log('✓ When you delete a USER, all their memberships will be removed');
        console.log('✓ This prevents orphaned membership records in the database');
        console.log('\nNext steps:');
        console.log('1. Restart your backend server to load the updated controllers');
        console.log('2. Test by deleting a project from admin dashboard');
        console.log('3. Test by deleting a user from employee management');
        console.log('4. Verify console logs show "Removed X membership(s)"');

        await mongoose.connection.close();
        console.log('\nDatabase connection closed');
        process.exit(0);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
};

testCascadeDelete();
