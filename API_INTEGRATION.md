# API Integration Status & Missing Endpoints

## ✅ Available Backend Endpoints (Port 5000)

### User Management
- ✅ `POST /api/v1/users/login` - User login
- ✅ `POST /api/v1/users/register` - Register new user (admin/user roles)
- ✅ `POST /api/v1/users/logout` - Logout (requires auth)
- ✅ `GET /api/v1/users` - Get all users
- ✅ `GET /api/v1/users/:id/projects` - Get projects for a specific user

### Project Management
- ✅ `GET /api/v1/projects` - Get all projects
- ✅ `GET /api/v1/projects/:id` - Get project by ID
- ✅ `POST /api/v1/projects` - Create new project
  - **Body**: `{ project_name, status, start_date, created_by }`
- ✅ `PUT /api/v1/projects/:id` - Update project
- ✅ `DELETE /api/v1/projects/:id` - Delete project

### Project Membership (Assigning users to projects with roles)
- ✅ `GET /api/v1/projects/members` - Get project members
  - **Body**: `{ project_id }`
- ✅ `POST /api/v1/projects/members` - Add member to project
  - **Body**: `{ project_id, user_id, role_id }`
- ✅ `PUT /api/v1/projects/members` - Update member's role
  - **Body**: `{ project_id, user_id, role_id }`
- ✅ `DELETE /api/v1/projects/members` - Remove member from project
  - **Body**: `{ project_id, user_id }`

### Role Management
- ✅ `GET /api/v1/roles` - Get all roles
- ✅ `GET /api/v1/roles/:id` - Get role by ID
- ✅ `POST /api/v1/roles` - Create new role
  - **Body**: `{ role_name, description }`
- ✅ `PUT /api/v1/roles/:id` - Update role
- ✅ `DELETE /api/v1/roles/:id` - Delete role

---

## 🔧 Flutter Services Implemented

### Core Services
1. **AuthService** (`lib/services/auth_service.dart`)
   - Login with email/password
   - Returns JWT token via cookie

2. **UserService** (`lib/services/user_service.dart`)
   - CRUD operations for users
   - Real-time stream with 3-second polling
   - Maps backend `role: 'admin'/'user'` to frontend

3. **ProjectService** (`lib/services/project_service.dart`)
   - CRUD operations for projects
   - Real-time stream with 3-second polling
   - Handles `created_by` population

4. **RoleService** (`lib/services/role_service.dart`)
   - CRUD operations for roles (Executor, Reviewer, SDH, etc.)
   - Real-time stream for role list

5. **ProjectMembershipService** (`lib/services/project_membership_service.dart`)
   - Assign/remove users to/from projects with specific roles
   - Get project members
   - Get user's projects

6. **SimpleHttp** (`lib/services/http_client.dart`)
   - Enhanced with `deleteJson()` for DELETE requests with body
   - Supports GET, POST, PUT, DELETE with JSON

---

## ❌ Missing Backend Endpoints

### High Priority (Required for full functionality)

#### 1. User Update & Delete
```
PUT /api/v1/users/:id
Body: { name, email, role }
Purpose: Edit existing users (e.g., change role, update info)

DELETE /api/v1/users/:id
Purpose: Remove users from system
```

#### 2. User Status Management (Optional but recommended)
```
PATCH /api/v1/users/:id/status
Body: { status: 'active' | 'inactive' }
Purpose: Activate/deactivate users without deleting
```
**Current workaround**: Frontend has a `status` field in `TeamMember` model but backend doesn't persist it.

#### 3. Project Description Field
**Issue**: Backend `Project` model doesn't have a `description` field.
**Recommendation**: Add optional `description` field to project schema.
```javascript
// In project.models.js
description: {
  type: String,
  trim: true
}
```

#### 4. Project Priority Field
**Issue**: Backend `Project` model doesn't have a `priority` field.
**Recommendation**: Add priority field for better project management.
```javascript
// In project.models.js
priority: {
  type: String,
  enum: ['low', 'medium', 'high'],
  default: 'medium'
}
```

---

## 📊 Data Model Mappings

### User/TeamMember Mapping
| Backend (MongoDB) | Frontend (Flutter) | Notes |
|------------------|-------------------|-------|
| `_id` | `id` | MongoDB ObjectId |
| `name` | `name` | Full name |
| `email` | `email` | Email address |
| `role: 'admin'/'user'` | `role: 'Admin'/'User'` | **Changed from previous Team Leader/Executor** |
| `createdAt` | `dateAdded` | Auto timestamp |
| `updatedAt` | `lastActive` | Auto timestamp |
| ❌ (missing) | `status` | Active/Inactive status not in backend |
| `password` (write-only) | `password` (write-only) | Only for creation |

### Project Mapping
| Backend | Frontend | Notes |
|---------|----------|-------|
| `_id` | `id` | MongoDB ObjectId |
| `project_name` | `title` | Project name |
| `status: pending/in_progress/completed` | `status: Not Started/In Progress/Completed` | Enum conversion |
| `start_date` | `started` | DateTime |
| `end_date` | ❌ | Backend has it, frontend doesn't use it yet |
| `created_by` (ObjectId/populated) | `executor` | Creator ID or name |
| ❌ | `description` | Not in backend |
| ❌ | `priority` | Not in backend |
| ❌ | `assignedEmployees` | Fetched via ProjectMembership |

### Role Mapping
| Backend | Frontend | Notes |
|---------|----------|-------|
| `_id` | `id` | MongoDB ObjectId |
| `role_name` | `roleName` | e.g., "Executor", "Reviewer", "SDH" |
| `description` | `description` | Optional role description |
| `createdAt` | `createdAt` | Auto timestamp |
| `updatedAt` | `updatedAt` | Auto timestamp |

### ProjectMembership Mapping
| Backend | Frontend | Notes |
|---------|----------|-------|
| `_id` | `id` | MongoDB ObjectId |
| `project_id` | `projectId` | Reference to Project |
| `user_id` | `userId` | Reference to User |
| `role` | `roleId` | Reference to Role (not user.role!) |
| `user_id` (populated) | `userName`, `userEmail` | Populated user data |
| `role` (populated) | `roleName`, `roleDescription` | Populated role data |

---

## 🚀 Usage Examples

### Creating a Project with Members

```dart
// 1. Create the project
final project = await projectService.create(Project(
  id: '',
  title: 'Quality Review System',
  started: DateTime.now(),
  priority: 'High',
  status: 'In Progress',
  executor: currentUserId, // created_by
));

// 2. Get or create roles
final roles = await roleService.getAll();
final executorRole = roles.firstWhere((r) => r.roleName == 'Executor');

// 3. Assign members to project
await membershipService.addMember(
  projectId: project.id,
  userId: 'user123',
  roleId: executorRole.id,
);
```

### Getting Project Members

```dart
final members = await membershipService.getProjectMembers(projectId);
for (var member in members) {
  print('${member.userName} - ${member.roleName}');
}
```

### Getting User's Projects

```dart
final userProjects = await membershipService.getUserProjects(userId);
```

---

## 🔐 Authentication Notes

- JWT tokens stored in HTTP-only cookies by backend
- Frontend `AuthService` extracts token from `Set-Cookie` header
- `SimpleHttp` includes token in `Authorization: Bearer <token>` header
- Logout endpoint clears the cookie and nullifies `accessToken` in DB

---

## 🎯 Next Steps

1. **Add missing User endpoints** (PUT, DELETE)
2. **Add project description and priority fields** to backend schema
3. **Consider adding user status field** for soft-delete functionality
4. **Implement pagination** for users/projects lists (optional, for scalability)
5. **Add filtering/search endpoints** (e.g., `GET /users?role=admin`)
6. **Add project statistics endpoint** (e.g., `GET /projects/:id/stats`)

---

## 📝 Notes

- **Port difference**: Original requirement mentioned port 5000, code shows 5000 in `ApiConfig.baseUrl`
- **Real-time updates**: Currently using 3-second polling via `Timer.periodic`. Consider WebSocket for instant updates.
- **Error handling**: All services throw exceptions with backend error messages
- **Role confusion**: Backend has two separate role concepts:
  1. **User role** (`user.role`): 'admin' or 'user' - permission level
  2. **Project role** (`Role` model): 'Executor', 'Reviewer', 'SDH' - project-specific responsibilities
