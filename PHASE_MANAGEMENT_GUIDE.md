# Dynamic Phase Management - Quick Start Guide

## 🎯 What's New?

The Checklist Template Management page now supports **dynamic phases** instead of the hardcoded 3 phases. You can now:

- ✨ Add unlimited phases with custom names
- ✏️ Rename phases to match your workflow
- 🗑️ Delete phases you don't need

---

## 📋 UI Overview

### Header Section

```
┌─────────────────────────────────────────────────────────────────┐
│  Checklist Template Management                                  │
│                                   [+Add Phase] [↻] [Categories] │
└─────────────────────────────────────────────────────────────────┘
```

**Buttons:**

- **+ Add Phase**: Create new phase with custom name
- **↻ (Refresh)**: Reload template data
- **Manage Categories**: Edit defect categories

### Phase Tabs Section

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1 ⋮  │  Phase 2 ⋮  │  Phase 3 ⋮  │                       │
│  ───────────────────────────────────────────────                │
│                                                                  │
│  [+Add Checklist Group]                                         │
│                                                                  │
│  ▼ Checklist Group 1                        [✏️] [🗑️]          │
│     • Question 1                            [✏️] [🗑️]          │
│     • Question 2                            [✏️] [🗑️]          │
│     + Add Question     + Add Section                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Phase Tab Actions (⋮ menu):**

- ✏️ **Rename**: Change phase name
- 🗑️ **Delete**: Remove phase permanently

---

## 🚀 How to Use

### 1. Adding a New Phase

**Steps:**

1. Click the **"+ Add Phase"** button in the header
2. Enter a custom name (e.g., "Kickoff Review", "Design Phase", "Final Review")
3. Click **"Save"**
4. New tab appears with your custom name

**Example:**

```
Before: │ Phase 1 │ Phase 2 │ Phase 3 │
After:  │ Phase 1 │ Phase 2 │ Phase 3 │ Kickoff Review │
```

### 2. Renaming a Phase

**Steps:**

1. Click the **⋮** (three dots) on the phase tab you want to rename
2. Select **"Rename"** from the menu
3. Enter the new name (e.g., change "Phase 1" to "Pre-Planning Review")
4. Click **"Save"**
5. Tab name updates immediately

**Example:**

```
Before: │ Phase 1 │ Phase 2 │ Phase 3 │
After:  │ Pre-Planning Review │ Design Review │ Final Review │
```

### 3. Deleting a Phase

**Steps:**

1. Click the **⋮** (three dots) on the phase tab you want to delete
2. Select **"Delete"** (red option) from the menu
3. Confirm deletion in the warning dialog
4. Phase and all its data are permanently removed

**⚠️ Warning:** Deleting a phase removes ALL checklist groups, sections, and questions within it. This action cannot be undone!

---

## 💡 Best Practices

### Naming Conventions

**Good Phase Names:**

- ✅ "Requirements Review"
- ✅ "Design Phase"
- ✅ "Implementation"
- ✅ "Testing & QA"
- ✅ "Final Delivery"

**Avoid:**

- ❌ "Phase X" (generic, not descriptive)
- ❌ "TODO" (not meaningful)
- ❌ Empty or very short names

### Organization Tips

1. **Match Your Workflow**: Name phases to match your actual project stages
   - Example: Software projects might use "Requirements → Design → Development → Testing → Deployment"
2. **Keep It Concise**: Phase names appear in tabs, so shorter is better
   - ✅ "Design Review" (good)
   - ❌ "Comprehensive Design and Architecture Review Phase" (too long)

3. **Use Consistent Terminology**: If you use "Review" in one phase name, consider using it consistently
   - Example: "Requirements Review", "Design Review", "Code Review"

4. **Start with 3-5 Phases**: Most projects don't need more than this
   - Add more only if your process requires them

---

## 🔧 Common Workflows

### Workflow 1: Customizing Default Phases

```
1. Rename "Phase 1" → "Kickoff Review"
2. Rename "Phase 2" → "Design & Planning"
3. Rename "Phase 3" → "Final Delivery"
```

### Workflow 2: Creating Industry-Specific Phases

```
For Manufacturing Projects:
1. Add "Concept Review"
2. Add "Design Verification"
3. Add "Process Validation"
4. Add "Production Release"
```

### Workflow 3: Multi-Stage Projects

```
For Agile Projects:
1. Add "Sprint Planning"
2. Add "Sprint Review"
3. Add "Sprint Retrospective"
4. Add "Release Review"
```

---

## ❓ Frequently Asked Questions

**Q: How many phases can I create?**
A: There's no hard limit. The system supports stage1 through stage99 (99 phases).

**Q: What happens to existing data when I rename a phase?**
A: All checklist groups, sections, and questions remain unchanged. Only the display name changes.

**Q: Can I reorder phases?**
A: Currently, phases appear in the order they were created. Drag-and-drop reordering is a future enhancement.

**Q: Will deleting a phase affect other phases?**
A: No. Deleting a phase only removes that specific phase and its data. Other phases remain intact.

**Q: Can I recover a deleted phase?**
A: No. Phase deletion is permanent. Always double-check before confirming deletion.

**Q: What's the difference between "Phase" and "Checklist Group"?**
A:

- **Phase**: Top-level organization (appears as tabs)
- **Checklist Group**: Container for related questions within a phase

---

## 🎨 Example Setup

Here's a complete example for a typical engineering project:

### Phase Structure:

```
┌──────────────────────────────────────────────────────────┐
│ Kickoff Review │ Design Review │ Implementation │ Testing │ Final Review │
└──────────────────────────────────────────────────────────┘
```

### Kickoff Review (Phase 1)

- **Group**: Project Scope
  - Question: Are project objectives clearly defined?
  - Question: Is the timeline realistic?
- **Group**: Resource Planning
  - Question: Are all team members assigned?
  - Question: Is equipment available?

### Design Review (Phase 2)

- **Group**: Design Documentation
  - Question: Are all drawings complete?
  - Question: Are calculations verified?
- **Group**: Standards Compliance
  - Question: Does design meet industry standards?

### Implementation (Phase 3)

- **Group**: Code Quality
  - Question: Is code properly documented?
  - Question: Are unit tests written?

### Testing (Phase 4)

- **Group**: Test Coverage
  - Question: Are all requirements tested?
  - Question: Are edge cases covered?

### Final Review (Phase 5)

- **Group**: Documentation
  - Question: Is user manual complete?
  - Question: Are all deliverables ready?

---

## 📞 Support

If you encounter any issues:

1. Try clicking the **Refresh** button (↻) to reload the template
2. Check that phase names don't contain special characters
3. Ensure you have admin permissions

---

**Last Updated**: January 2025  
**Version**: 2.0 (Dynamic Phase Management)
