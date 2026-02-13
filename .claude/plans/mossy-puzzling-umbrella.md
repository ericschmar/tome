# AddBookView Form Layout Fix

## Context
The "Add Book Manually" page (AddBookView) currently has layout issues on iOS where form sections overlap on smaller screens. The current implementation uses:
- ScrollView + VStack + GroupBox structure
- ResponsiveHStack that switches orientation at 700px threshold
- Horizontal HStacks for paired fields (ISBN+Year, Publisher+Pages)

This structure causes overlapping and cramped layout on iOS devices with smaller screens.

## Solution
Replace the current ScrollView + VStack + GroupBox layout with SwiftUI's native `Form` container, which works on both iOS and macOS and automatically provides proper section-based layouts.

## Critical Files
- `/Users/mmacbook/develop/tome/tome/Views/AddBookView.swift` - Main file to modify

## Implementation Plan

### 1. Replace Layout Container
Replace the ScrollView + VStack + GroupBox structure with Form + Section:

**Current structure (remove):**
```swift
ScrollView {
  VStack(spacing: 24) {
    // Header
    // ResponsiveHStack
    // GroupBox sections
  }
}
```

**New structure:**
```swift
Form {
  // Header (outside Section for full-width display)
  // Sections with form fields
}
```

### 2. Reorganize Form Sections
Transform the current GroupBox sections into Form Sections:

**Current sections to convert:**
1. Cover Image Section → Section (or keep outside Form for full width)
2. Essential Information → Section("Essential Information") { ... }
3. Publication Details → Section("Publication Details") { ... }
4. Description → Section("Description") { ... }
5. Action Buttons → Section with buttons

**Key changes:**
- Use `Section { }` instead of `GroupBox { }`
- Place fields vertically (one per row) instead of horizontal HStacks
- Remove ResponsiveHStack - use Form's built-in responsive behavior
- Use `TextField` and `TextEditor` directly in Form sections

### 3. Preserve All Existing Functionality
Keep all existing features intact:
- FocusState management for all text fields
- iOS-specific keyboard types (.numberPad, .numbersAndPunctuation)
- Form validation (isFormValid, isFormEmpty)
- Cover image selection and display
- Clear and Add Book button actions
- All state variables and bindings

### 4. Maintain Platform-Specific Details
Preserve existing platform conditionals:
- TextEditor background color (.systemBackground on iOS, .textBackgroundColor on macOS)
- Keyboard type adjustments for numeric fields
- Any other existing `#if os(iOS)` blocks

## Implementation Details

### New Unified Form Structure:
```swift
Form {
  // Header section (outside Form Section for full width)
  VStack {
    Image(systemName: "book.fill")
      .foregroundStyle(...)
    Text("Add Book Manually")
      .font(.title)
    Text("Enter details manually")
      .foregroundStyle(.secondary)
  }

  // Cover image section
  Section {
    BookCoverView(...)
  }

  // Essential information
  Section("Essential Information") {
    TextField("Title", text: $title)
      .focused($focusedField, equals: .title)
    TextField("Authors", text: $authors)
      .focused($focusedField, equals: .authors)
  }

  // Publication details - vertical layout (not horizontal)
  Section("Publication Details") {
    TextField("ISBN", text: $isbn)
      .focused($focusedField, equals: .isbn)
    TextField("Year", value: $year, format: .number)
      .focused($focusedField, equals: .year)
    TextField("Publisher", text: $publisher)
      .focused($focusedField, equals: .publisher)
    TextField("Pages", value: $pages, format: .number)
      .focused($focusedField, equals: .pages)
  }

  // Description
  Section("Description") {
    TextEditor(text: $description)
  }

  // Actions
  Section {
    Button("Clear") { /* clear action */ }
    Button("Add Book") { /* add action */ }
      .disabled(!isFormValid)
  }
}
```

## Verification
1. Test on iOS device/simulator:
   - Verify no overlapping sections
   - Confirm single-column vertical layout
   - Check all text fields are accessible and keyboard works properly
   - Test form validation and button states
   - Verify cover image selection works
   - Test scrolling through entire form

2. Test on macOS:
   - Verify form layout looks good on macOS (Form works on both platforms)
   - Confirm all functionality still works
   - Check that section headers and spacing look appropriate

3. Test form submission on both platforms:
   - Fill all fields and verify book is added correctly
   - Test clear button functionality
   - Verify validation rules apply

## Notes
- SwiftUI Form component works natively on both iOS and macOS
- Keep all @State, @FocusState, and other property declarations (they're shared)
- Form automatically provides proper spacing and section styling
- Cover image section may need to be outside the Form for full-width display
