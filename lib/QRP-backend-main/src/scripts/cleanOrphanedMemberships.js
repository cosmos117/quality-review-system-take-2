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