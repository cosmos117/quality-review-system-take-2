# Dynamic Phase Management Implementation

## Overview

The Checklist Template Management page has been transformed from a hardcoded 3-phase system to a dynamic phase management system where administrators can add, rename, and delete phases with custom names.

## Changes Made

### 1. **Added PhaseModel Class**

- Location: [lib/pages/admin_pages/admin_checklist_template_page.dart](lib/pages/admin_pages/admin_checklist_template_page.dart#L7-L19)
- Purpose: Encapsulates phase data including id, name, stage identifier, and groups
- Structure:
  ```dart
  class PhaseModel {
    String id;
    String name;
    String stage; // stage1, stage2, stage3, etc.
    List<TemplateGroup> groups;
  }
  ```

### 2. **Updated State Management**

- **Before**: Separate variables `_p1Groups`, `_p2Groups`, `_p3Groups` for 3 hardcoded phases
- **After**: Single `List<PhaseModel> _phases` for dynamic number of phases
- **Benefits**: Scalable to any number of phases, cleaner code architecture

### 3. **Dynamic Tab Generation**

- Tabs are now generated dynamically from `_phases` list
- Each tab includes a popup menu with:
  - **Rename**: Change phase name (e.g., "Phase 1" → "Kick-Off Review")
  - **Delete**: Remove phase and all its data
- Made TabBar scrollable to support many phases: `isScrollable: true`

### 4. **New Phase Management Methods**

#### `_addPhase()`

- Prompts for phase name
- Creates new phase with next available stage number (stage4, stage5, etc.)
- Automatically switches to new phase tab

#### `_renamePhase(PhaseModel phase)`

- Shows dialog to rename phase
- Updates phase name in real-time
- Example: "Phase 1" → "Planning Review", "Phase 2" → "Design Review"

#### `_deletePhase(PhaseModel phase)`

- Confirms deletion with warning dialog
- Removes phase and updates TabController
- Adjusts selected tab if needed

#### `_promptPhaseName({String? initial})`

- Reusable dialog for phase naming

### 5. **Updated TemplateService for Dynamic Stages**

- Location: [lib/services/template_service.dart](lib/services/template_service.dart)
- **Before**: Hardcoded validation for only `stage1`, `stage2`, `stage3`
- **After**: Dynamic validation using regex pattern `^stage[1-9]\d*$`

#### Added `_isValidStage(String stage)` method:

```dart
bool _isValidStage(String stage) {
  // Match stage1, stage2, stage3, ..., stage99
  return RegExp(r'^stage[1-9]\d*$').hasMatch(stage);
}
```

#### Updated Methods:

- `fetchTemplate()` - Supports dynamic stage filtering
- `addChecklist()` - Accepts any stage format
- `updateChecklist()` - Validates with \_isValidStage
- `deleteChecklist()` - Validates with \_isValidStage
- `addCheckpoint()` - Validates with \_isValidStage
- `updateCheckpoint()` - Validates with \_isValidStage
- `deleteCheckpoint()` - Validates with \_isValidStage
- `addSection()` - Validates with \_isValidStage
- `updateSection()` - Validates with \_isValidStage
- `deleteSection()` - Validates with \_isValidStage

### 6. **Updated \_PhaseEditor Widget**

- Added `stage` parameter to receive stage identifier directly
- **Before**: `String get _stage => 'stage${widget.phaseIndex + 1}'`
- **After**: `String get _stage => widget.stage`
- More explicit and avoids calculation errors

### 7. **Backward Compatibility**

- System initializes with default 3 phases (Phase 1, Phase 2, Phase 3)
- Existing backend data with stage1, stage2, stage3 continues to work
- New phases use stage4, stage5, etc. following the same pattern

## User Interface Features

### Header Actions:

1. **"Add Phase" button**: Creates new phase with custom name
2. **Refresh button**: Reloads template from backend
3. **"Manage Categories" button**: Opens defect category manager

### Phase Tab Features:

- Each tab shows phase name
- Three-dot menu on each tab for:
  - Edit icon: Rename phase
  - Delete icon (red): Remove phase with confirmation

### Example Usage Flow:

1. Click "Add Phase" → Enter "Kick-Off Review" → Phase tab created
2. Click "Add Phase" → Enter "Design Review" → Another phase added
3. Right-click on "Phase 1" → Rename → "Pre-Planning Review"
4. Right-click on unwanted phase → Delete → Confirm removal

## Technical Benefits

### Scalability:

- Support unlimited number of phases
- No code changes needed to add/remove phases

### Flexibility:

- Custom phase names instead of generic "Phase 1", "Phase 2"
- Phases can be named by project type (e.g., "Requirements", "Implementation", "Testing")

### Maintainability:

- Single loop generates all tabs
- Single PhaseModel class manages all phase data
- Cleaner, more maintainable code structure

### Data Integrity:

- Stage validation ensures proper format (stage1, stage2, ...)
- Backend compatibility maintained through stage naming convention

## Backend Compatibility

The backend MongoDB template structure remains compatible:

- Template document contains: `stage1`, `stage2`, `stage3`, etc.
- Each stage contains array of checklists
- Each checklist contains sections and checkpoints

Frontend now dynamically maps phase names to stage identifiers:

- "Kick-Off Review" → `stage1`
- "Design Review" → `stage2`
- "Final Review" → `stage3`
- Custom phases → `stage4`, `stage5`, etc.

## Testing Checklist

✅ Add new phase with custom name
✅ Rename existing phase
✅ Delete phase (confirm dialog)
✅ Add checklist groups within new phase
✅ Add questions/sections within new phase groups
✅ Navigate between multiple phases
✅ Reload template preserves phase data
✅ Backend service validates dynamic stages
✅ No errors in Dart analysis

## Migration Notes

**No migration required** - System is backward compatible with existing 3-phase templates. Admins can:

- Keep using 3 default phases
- Rename default phases to meaningful names
- Add additional phases as needed

## Future Enhancements (Optional)

1. **Phase Reordering**: Drag-and-drop to reorder phases
2. **Phase Templates**: Save/load phase configurations
3. **Phase Cloning**: Duplicate existing phase with all groups
4. **Phase Metadata**: Add description, owner, due dates per phase
5. **Backend Phase CRUD**: Add dedicated API endpoints for phase management (currently phases are implicit via stage naming)

---

**Implementation Date**: 2025-01-XX  
**Modified Files**:

- [lib/pages/admin_pages/admin_checklist_template_page.dart](lib/pages/admin_pages/admin_checklist_template_page.dart)
- [lib/services/template_service.dart](lib/services/template_service.dart)
