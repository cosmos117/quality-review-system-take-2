import mongoose from 'mongoose';
import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import dotenv from 'dotenv';

dotenv.config();

const cleanOrphanedMemberships = async () => {
    try {
        // Connect to database
        await mongoose.connect(process.env.MONGO_DB_URI);
        console.log('Connected to MongoDB');

        // Get all memberships
        const allMemberships = await ProjectMembership.find({});
        console.log(`\nTotal memberships: ${allMemberships.length}`);

        let orphanedCount = 0;
        const orphanedIds = [];

        // Check each membership
        for (const membership of allMemberships) {
            const userExists = await User.findById(membership.user_id);
            const projectExists = await Project.findById(membership.project_id);
            
            if (!userExists) {
                console.log(`Found orphaned membership: ${membership._id} (deleted user_id: ${membership.user_id}, project_id: ${membership.project_id})`);
                orphanedIds.push(membership._id);
                orphanedCount++;
            } else if (!projectExists) {
                console.log(`Found orphaned membership: ${membership._id} (user_id: ${membership.user_id}, deleted project_id: ${membership.project_id})`);
                orphanedIds.push(membership._id);
                orphanedCount++;
            }
        }

        console.log(`\nFound ${orphanedCount} orphaned membership(s)`);

        if (orphanedCount > 0) {
            console.log('\nDeleting orphaned memberships...');
            const result = await ProjectMembership.deleteMany({
                _id: { $in: orphanedIds }
            });
            console.log(`Deleted ${result.deletedCount} orphaned membership(s)`);
        } else {
            console.log('\nNo orphaned memberships to clean up!');
        }

        await mongoose.connection.close();
        console.log('\nDatabase connection closed');
        process.exit(0);
    } catch (error) {
        console.error('Error cleaning orphaned memberships:', error);
        process.exit(1);
    }
};

cleanOrphanedMemberships();
