# iOS Book List Navigation Fix Plan

## Context

When tapping on a book in any list (library, search results, add book views), the app currently doesn't navigate properly on iOS. The book detail view should slide in with a back button in the top-left to return to the list. The list state (scroll position, filters, search text) should be preserved when returning.

**Goal**: Fix iOS book list navigation so that:
- Tapping a book navigates to BookContentView with standard iOS push transition
- Back button appears in top-left to return to the list
- List state is preserved (scroll position, filters, search text)
- Works for ALL book lists (library, search results, add book views)
- macOS behavior remains completely unchanged

## Problem Analysis

### Current iOS Implementation
- `NavigationRootView.swift` uses `NavigationStack` with `iOSMainContent` showing `contentForDestination()`
- List views (`LibraryContentListView`, `AddBookView`) use Button taps that set `selectedBook` binding
- No actual navigation occurs - lists just update selection state
- `BookContentView` has `onBack` callback but never gets pushed to navigation stack

### Current macOS Implementation
- Uses `NavigationSplitView` with three-column layout (sidebar, content, detail)
- Selection updates in list views automatically show `BookContentView` in detail pane
- Navigation is state-based, not stack-based

## Critical Files

- `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift` - Main navigation structure (iOS: NavigationStack, macOS: NavigationSplitView)
- `/Users/mmacbook/develop/tome/tome/Views/BookContentView.swift` - Detail view with onBack/onAdd/onDelete callbacks
- `/Users/mmacbook/develop/tome/tome/ViewModels/NavigationState.swift` - Has selectedBook and selectedSearchResult properties
- `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift` (lines 302-421) - LibraryContentListView with BookCard/List that sets selectedBook

## Implementation Approach

### Use NavigationStack's `.navigationDestination()` Modifier (iOS-only)

SwiftUI's NavigationStack provides automatic state preservation and back button management when using `.navigationDestination(item:)` modifier.

**How It Works:**
- Observe a binding (`$navigationState.selectedBook`)
- When binding changes from nil to non-nil → automatically pushes destination view
- When binding changes from non-nil to nil → automatically pops back to source view
- All `@State` variables in source view automatically preserved (scroll, filters, search)

**Why This Approach:**
1. Minimal changes - only modify `iOSMainContent` in NavigationRootView.swift
2. No changes to list views - they already use correct pattern (setting selectedBook binding)
3. Automatic state preservation - NavigationStack handles all @State preservation
4. Native iOS navigation - Standard push/pop transitions with back button
5. Separate handling for library books vs search results with appropriate callbacks

## Implementation Steps

### 1. Modify `iOSMainContent` in NavigationRootView.swift

**File**: `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift` (lines 114-152)

Add two `.navigationDestination()` modifiers after the `.sheet()` modifier:

```swift
#if os(iOS)
@ViewBuilder
private var iOSMainContent: some View {
    contentForDestination(navigationState.selectedDestination)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        navigationState.isSidebarPresented = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { navigationState.isSidebarPresented },
            set: { navigationState.isSidebarPresented = $0 }
        )) {
            LibrarySidebar(...)
        }
        .navigationDestination(item: $navigationState.selectedBook) { book in
            BookContentView(
                source: .library(book),
                onBack: {
                    navigationState.selectedBook = nil
                },
                onDelete: {
                    viewModel?.deleteBook(book)
                }
            )
        }
        .navigationDestination(item: $navigationState.selectedSearchResult) { result in
            BookContentView(
                source: .search(result),
                onAdd: {
                    addBookFromSearch(result)
                },
                onBack: {
                    navigationState.selectedSearchResult = nil
                }
            )
        }
}
#endif
```

**Key Points:**
- Both modifiers use `item` parameter (Binding) to observe navigation state changes
- Library books use `selectedBook` binding with `onDelete` callback
- Search results use `selectedSearchResult` binding with `onAdd` callback
- `onBack` callbacks clear selection, which automatically pops the view

### 2. No Changes Needed to List Views

**LibraryContentListView.swift** (lines 367-381)
- Current code: `selectedBook = book` in Button taps
- This is already correct - sets the binding that `.navigationDestination()` observes
- No changes needed

**AddBookView.swift** (lines 143-149)
- Current code: `onResultSelected(result)` sets `navigationState.selectedSearchResult`
- This is already correct - sets the binding that `.navigationDestination()` observes
- No changes needed

**Why No Changes Needed:**
When `selectedBook` or `selectedSearchResult` binding is set to a non-nil value:
- `.navigationDestination(item:)` modifier observes the change
- NavigationStack automatically pushes the BookContentView onto stack
- Standard iOS back button appears automatically

### 3. State Preservation Mechanism

NavigationStack automatically preserves all state in the view hierarchy:

**What Gets Preserved:**
- ScrollView position (scroll depth in lists)
- All `@State` variables (filters, sort options, search text)
- View model state (LibraryViewModel properties)
- Selection state (currently selected items)

**Example User Flow:**
1. User opens "All Books" list, scrolls to position 50, applies filter "Reading Status: To Read"
2. Taps book at position 50
3. BookContentView slides in from right (standard iOS push transition)
4. User views book details, taps back button (top left)
5. List appears at **same scroll position 50**, filter **still applied**, all **state preserved**

**No Manual State Management Required:**
Unlike UIKit, SwiftUI's NavigationStack handles all state preservation automatically.

### 4. macOS Behavior Preservation

**All changes wrapped in `#if os(iOS)` blocks:**
- macOS code path completely unchanged
- No `.navigationDestination()` modifiers added to macOS path
- NavigationSplitView continues to work as before
- Three-column layout intact

## Verification

### iOS Testing - Library Books

1. Build and run on iOS Simulator
2. Navigate to "All Books" from sidebar
3. Scroll list to middle position
4. Apply filter (e.g., Reading Status: To Read)
5. Tap any book
   - ✅ BookContentView should slide in from right
   - ✅ Back button should appear in top-left with book title
   - ✅ Delete button should appear in top-right (for library books)
6. Tap back button
   - ✅ List should appear at same scroll position
   - ✅ Filter should still be applied
   - ✅ Selection should be cleared

### iOS Testing - Search Results

1. Navigate to "Search" (Add Book > Search)
2. Enter search query (e.g., "Swift")
3. Tap any search result
   - ✅ BookContentView should slide in from right
   - ✅ Back button should appear in top-left
   - ✅ "Add to Library" button should be visible
4. Tap back button
   - ✅ Search results should reappear
   - ✅ Search text should be preserved
   - ✅ Scroll position should be maintained
5. Tap "Add to Library" button
   - ✅ Should navigate to "All Books"
   - ✅ New book should be selected
   - ✅ BookContentView should show with library features (edit/delete)

### iOS Testing - Delete Flow

1. Open a library book
2. Tap delete button
3. Confirm deletion
   - ✅ Book should be deleted
   - ✅ Should return to list view
   - ✅ Book should no longer appear in list

### macOS Testing - Regression Check

1. Build and run on Mac
2. Navigate to "All Books"
3. Select book
   - ✅ Three-column layout should work
   - ✅ Book should appear in detail pane (right column)
   - ✅ No navigation stack should be used
4. Change sidebar selection
   - ✅ Detail pane should update appropriately
   - ✅ No regressions in macOS behavior

## Notes

- Only `NavigationRootView.swift` requires changes (specifically `iOSMainContent`)
- List views (`LibraryContentListView`, `AddBookView`) already use correct pattern - no changes needed
- `BookContentView.swift` already has proper callbacks (`onBack`, `onAdd`, `onDelete`) - no changes needed
- All changes wrapped in `#if os(iOS)` to guarantee macOS behavior unchanged
- NavigationStack provides automatic state preservation - no manual state management needed
