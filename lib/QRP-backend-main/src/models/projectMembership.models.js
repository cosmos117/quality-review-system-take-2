import mongoose from 'mongoose';

const projectMembershipSchema = new mongoose.Schema({
    /**
     * Links to the project document.
     */
    project_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Project',
        required: true
    },

    /**
     * Links to the user document.
     */
    user_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },

    /**
     * This is the link to the 'Role' document's _id.
     * This 'ref' allows you to use .populate()
     */
    role: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Role', // This tells Mongoose to link to the 'Role' model
        required: true
    }
}, {
    timestamps: { createdAt: true, updatedAt: false }
});

// Existing unique index for data integrity
projectMembershipSchema.index({ project_id: 1, user_id: 1, role: 1 }, { unique: true });

// Additional indexes for common queries
projectMembershipSchema.index({ project_id: 1 });
projectMembershipSchema.index({ user_id: 1 });
projectMembershipSchema.index({ project_id: 1, user_id: 1 });

const ProjectMembership = mongoose.model('ProjectMembership', projectMembershipSchema);

export default ProjectMembership;
