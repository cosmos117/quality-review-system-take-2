import mongoose from 'mongoose';
import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import dotenv from 'dotenv';

dotenv.config();

const testCascadeDelete = async () => {
    try {
        await mongoose.connect(process.env.MONGO_DB_URI);        // Test 1: Check current state        const allProjects = await Project.find({});
        const allUsers = await User.find({});
        const allMemberships = await ProjectMembership.find({});        // Test 2: Show memberships per project        for (const project of allProjects) {
            const memberships = await ProjectMembership.find({ project_id: project._id });            if (memberships.length > 0) {
                for (const m of memberships) {
                    const user = await User.findById(m.user_id);                }
            }
        }        // Test 3: Show memberships per user        for (const user of allUsers) {
            const memberships = await ProjectMembership.find({ user_id: user._id });            if (memberships.length > 0) {
                for (const m of memberships) {
                    const project = await Project.findById(m.project_id);                }
            }
        }        await mongoose.connection.close();        process.exit(0);
    } catch (error) {        process.exit(1);
    }
};

testCascadeDelete();
