# Auto-Focus Search Bars on Add Book Screens

## Context
Currently, when users navigate to the "Add Book" or "Bulk Add Books" screens, they must manually click into the search field before typing. This adds friction to the workflow. The BulkAddBooksView already has auto-focus implemented, but AddBookView does not.

## Goal
Make the search field automatically receive focus when the user first navigates to either the Add Book or Bulk Add Books screens, allowing users to start typing immediately.

## Current State
- ✅ **BulkAddBooksView**: Already has auto-focus working
- ❌ **AddBookView**: Missing auto-focus for search field

## Implementation

### File: `Tome/Views/AddBookView.swift`

**Location**: `AddBookSearchView` struct (lines 56-225)

**Changes Required**:

1. **Add @FocusState property** (after line 59):
   ```swift
   @FocusState private var isSearchFocused: Bool
   ```

2. **Add .focused() modifier** (after line 89, after `.searchable()`):
   ```swift
   .focused($isSearchFocused)
   ```

3. **Add .onAppear modifier** (after the new `.focused()` modifier):
   ```swift
   .onAppear {
       isSearchFocused = true
   }
   ```

### File: `Tome/Views/Sidebar/BulkAddBooksView.swift`

**Status**: ✅ Already implemented (lines 8, 204, 218-221)

No changes needed - this view already has:
- `@FocusState private var isSearchFocused: Bool` (line 8)
- `.focused($isSearchFocused)` modifier (line 204)
- `.onAppear { isSearchFocused = true }` (lines 218-221)

## Complete Modified Code Section for AddBookView

The modifiers section of `AddBookSearchView` (lines 86-103) will become:

```swift
.searchable(
    text: $viewModel.searchQuery,
    prompt: "Search by title, author, or ISBN"
)
.focused($isSearchFocused)
.onAppear {
    isSearchFocused = true
}
.onSubmit(of: .search) {
    Task {
        await performSearch()
    }
}
.onChange(of: viewModel.searchQuery) { oldValue, newValue in
    // Auto-search when ISBN format is detected (10 or 13 digits)
    if isISBNQuery && (newValue.filter { $0.isNumber }.count == 10 || newValue.filter { $0.isNumber }.count == 13) {
        Task {
            await performSearch()
        }
    }
}
```

## Verification

### Manual Testing
1. **Test Add Book Screen**:
   - Navigate to Add Book screen
   - Verify keyboard focus is in search field
   - Start typing without clicking
   - Verify search works immediately

2. **Test Bulk Add Books Screen**:
   - Navigate to Bulk Add Books screen
   - Verify existing auto-focus still works
   - Start typing without clicking
   - Verify search works immediately

3. **Test Navigation**:
   - Navigate away and back to both screens
   - Verify focus returns each time
   - Test with both mouse and keyboard navigation

### Edge Cases to Verify
- Focus works on both macOS and iOS
- Focus is maintained after ISBN auto-search
- Focus can be manually moved away (e.g., to buttons)
- Focus returns when navigating back to the screen

## Summary

**Files to modify**: 1 file (`Tome/Views/AddBookView.swift`)
**Lines to add**: ~5 lines
**Pattern to follow**: Match the existing implementation in `BulkAddBooksView.swift`

This is a simple, low-risk change that improves UX by reducing friction in the book addition workflow.
