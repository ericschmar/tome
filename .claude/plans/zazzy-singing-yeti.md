# Migration Plan: Modal Navigation to Sidebar Navigation

## Context

The Tome app currently uses a modal-heavy TabView navigation pattern that feels more iOS-like than native macOS. The user wants to migrate to a modern macOS sidebar navigation pattern using `NavigationSplitView` to create a more native desktop experience.

**Current Issues:**
- TabView with 3 tabs (Library, Add, Settings) doesn't scale well for desktop
- Heavy use of modal sheets for main content (AddBookView, BookDetailView, FilterSheet)
- Each modal requires dismiss/close actions, breaking flow
- Book management requires multiple modal layers
- Not optimized for larger desktop screens

**Desired Outcome:**
- Native macOS three-column layout (Sidebar | Content | Detail)
- Persistent sidebar for navigation between sections
- AddBookView as a full page instead of modal
- BookDetailView in detail pane instead of modal sheet
- Filter controls inline or in popover instead of full sheet
- Better utilization of screen real estate
- More professional macOS application feel

## Implementation Approach

### Architecture Pattern
Use SwiftUI's `NavigationSplitView` with three columns:
1. **Sidebar**: Navigation destinations (Library sections, Add Books, Tags, Settings)
2. **Content**: Book list/grid view filtered by sidebar selection
3. **Detail**: Selected book details

### Navigation State Management
Create centralized `NavigationState` class to manage:
- Sidebar selection (destination enum)
- Content selection (selected book)
- Filter and sort state
- Column visibility

### Sidebar Structure
```
📚 Library
  - All Books
  - Currently Reading
  - To Read
  - Read

➕ Actions
  - Add Books

🏷️ Tags (dynamic section from data)

⚙️ System
  - Settings
```

### Migration Strategy
1. Create new navigation infrastructure (NavigationState, LibrarySidebar)
2. Replace TabView with NavigationSplitView in NavigationRootView
3. Remove NavigationStack wrappers from child views (provided by parent)
4. Convert modals to inline content or popover
5. Add destination-based filtering to LibraryViewModel
6. Wire up navigation state throughout the app

## Files to Create

### 1. `/Users/mmacbook/develop/tome/tome/ViewModels/NavigationState.swift`
Centralized navigation state management.

**Purpose:**
- Define `NavigationDestination` enum for sidebar items
- Manage sidebar selection, book selection, and filter state
- Provide reactive state with @Observable
- Control column visibility

**Key Components:**
```swift
@MainActor @Observable
final class NavigationState {
    var selectedDestination: NavigationDestination = .allBooks
    var selectedBook: Book?
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
}

enum NavigationDestination: Hashable {
    case allBooks, currentlyReading, toRead, read
    case addBooks
    case tag(Tag)
    case settings
}
```

### 2. `/Users/mmacbook/develop/tome/tome/Views/Sidebar/LibrarySidebar.swift`
Sidebar navigation component.

**Purpose:**
- Display navigation sections (Library, Actions, Tags, System)
- Bind to NavigationState for selection
- Use standard macOS sidebar styling
- Dynamic tags section from @Query

**Key Features:**
- List with sections and proper styling
- Icons and labels for each destination
- Badge counts for reading status items
- Dynamic tags section

## Files to Modify

### 3. `/Users/mmacbook/develop/tome/tome/tomeApp.swift`
**Changes:**
- Add `@State var navigationState = NavigationState()`
- Pass navigationState to NavigationRootView as environment object

### 4. `/Users/mmacbook/develop/tome/tome/Views/NavigationRootView.swift`
**Critical Changes:**
- Replace `TabView` with `NavigationSplitView`
- Implement three-column layout (sidebar, content, detail)
- Add switch/case for content based on destination
- Wire up NavigationState bindings
- Handle column visibility state
- Add empty detail view when no book selected

**Structure:**
```swift
NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
    // Sidebar
    LibrarySidebar(selectedDestination: $navigationState.selectedDestination)
} content: {
    // Content area (based on destination)
    contentForDestination(navigationState.selectedDestination)
} detail: {
    // Detail area
    if let book = navigationState.selectedBook {
        BookDetailView(book: book)
    } else {
        ContentUnavailableView("No Book Selected", ...)
    }
}
```

### 5. `/Users/mmacbook/develop/tome/tome/Views/LibraryListView.swift`
**Major Changes:**
- Remove `NavigationStack` wrapper (provided by parent)
- Remove `.sheet(item: $selectedBook)` - book detail now in detail pane
- Remove `.sheet(isPresented: $showingAddBook)` - add books is now sidebar destination
- Change `selectedBook` from local @State to @Binding parameter
- Add `destination: NavigationDestination` parameter
- Add destination-based filtering logic
- Convert `FilterSheet` from `.sheet` to `.popover` or inline toolbar controls

**New Signature:**
```swift
struct LibraryListView: View {
    @Bindable var viewModel: LibraryViewModel
    let destination: NavigationDestination
    @Binding var selectedBook: Book?
    // Remove: @State private var showingAddBook, selectedBook, showingFilters
}
```

**Filter Changes:**
- Move from full sheet to toolbar popover with filter button
- Or inline filter bar above list/grid
- Keep filter state in NavigationState or LibraryViewModel

### 6. `/Users/mmacbook/develop/tome/tome/ViewModels/LibraryViewModel.swift`
**New Method:**
```swift
func books(for destination: NavigationDestination) -> [Book] {
    switch destination {
    case .allBooks:
        return filteredBooks
    case .currentlyReading:
        return filteredBooks.filter { $0.readingStatus == .reading }
    case .toRead:
        return filteredBooks.filter { $0.readingStatus == .toRead }
    case .read:
        return filteredBooks.filter { $0.readingStatus == .read }
    case .tag(let tag):
        return filteredBooks.filter { $0.tags.contains(tag) }
    default:
        return filteredBooks
    }
}
```

**Consideration:** Move filter state (searchText, selectedStatus, selectedTag, sortOption) to NavigationState for centralized management.

### 7. `/Users/mmacbook/develop/tome/tome/Views/AddBookView.swift`
**Changes:**
- Remove `@Environment(\.dismiss)` - no longer a modal
- Remove "Cancel" button from toolbar
- Remove `NavigationStack` wrapper
- Add completion callback: `onBookAdded: (Book) -> Void`
- After adding book, navigate back to library and select new book

**Flow:**
1. User adds book via AddBookView
2. Book is saved
3. Callback triggers with new book
4. Navigation changes to `.allBooks`
5. New book is selected in detail view

### 8. `/Users/mmacbook/develop/tome/tome/Views/BookDetailView.swift`
**Changes:**
- Remove `NavigationStack` wrapper (provided by parent)
- Remove "Close" button (no longer needed)
- Keep EditBookView as sheet (appropriate for short-lived modal)
- Remove `@Environment(\.dismiss)` usage
- Handle being displayed with nil binding (use optional binding in parent)

**Note:** Will be displayed in detail pane, so no navigation chrome needed.

### 9. `/Users/mmacbook/develop/tome/tome/Views/Components/FilterControls.swift` (Optional)
**New Component:**
If converting FilterSheet to inline controls, create reusable filter component:
- Sort option picker
- Status filter chips
- Tag filter picker
- Statistics display

Can be used in toolbar popover or inline above list.

## Implementation Steps

### Phase 1: Infrastructure (Non-Breaking)
1. Create `NavigationState.swift` with destination enum and state management
2. Create `LibrarySidebar.swift` with sidebar navigation UI
3. Add `books(for destination:)` method to LibraryViewModel
4. Update `tomeApp.swift` to create and provide NavigationState

### Phase 2: Navigation Root
1. Rewrite `NavigationRootView.swift` with NavigationSplitView
2. Implement three-column layout
3. Add destination-based content switching
4. Test sidebar navigation works

### Phase 3: View Migrations
1. Migrate `LibraryListView.swift`:
   - Remove NavigationStack
   - Remove sheet presentations
   - Add destination parameter and binding
   - Convert FilterSheet to popover

2. Migrate `AddBookView.swift`:
   - Remove dismiss environment
   - Add completion callback
   - Update navigation after adding

3. Migrate `BookDetailView.swift`:
   - Remove NavigationStack
   - Remove dismiss button
   - Update for detail pane context

### Phase 4: Polish
1. Add empty states for detail pane
2. Add keyboard shortcuts (Cmd+1,2,3 for sections)
3. Test state restoration on app launch
4. Ensure sidebar collapse/expand works
5. Add badges/counts to sidebar items

## Verification

### Functional Testing
- [ ] Sidebar navigation changes content area
- [ ] Book selection shows details in detail pane
- [ ] "Add Books" shows AddBookView as content (not modal)
- [ ] Adding book navigates to library and selects new book
- [ ] Status filters in sidebar work (Currently Reading, To Read, Read)
- [ ] Tag filters in sidebar work
- [ ] Filter controls work (popover or inline)
- [ ] Edit book still works as sheet
- [ ] Delete book works and clears selection
- [ ] Empty state shows when no book selected
- [ ] Search works across all contexts
- [ ] Statistics display correctly

### UI/UX Testing
- [ ] Three-column layout displays correctly
- [ ] Sidebar is collapsible
- [ ] Column widths are appropriate
- [ ] Navigation feels native macOS
- [ ] No modal jank or double modals
- [ ] Smooth transitions between destinations
- [ ] Proper window resizing behavior

### Regression Testing
- [ ] All existing features still work
- [ ] Data persistence works correctly
- [ ] No duplicate navigation stacks
- [ ] Memory management is correct
- [ ] No retain cycles from bindings

## Critical Considerations

### Navigation Stack Management
**Issue:** Avoid double NavigationStacks
**Solution:** Parent (NavigationSplitView) provides stack context, child views don't wrap in NavigationStack

### Filter State
**Decision Point:** Where to store filter state?
- **Option A:** Keep in LibraryViewModel (current approach)
- **Option B:** Move to NavigationState (centralized)

**Recommendation:** Move to NavigationState for consistency with sidebar-driven filtering

### Edit Flow
**Issue:** EditBookView currently a sheet
**Options:**
- Keep as sheet (recommended for now)
- Make inline editing in detail view (future enhancement)

**Recommendation:** Keep as sheet - modal is appropriate for temporary editing

### Empty States
**Issue:** What to show when no book selected?
**Solution:** Use `ContentUnavailableView` in detail pane with prompt to select a book

### Search
**Decision Point:** Per-view or global search?
**Recommendation:** Global search in toolbar that searches current destination's books

### Data Refresh
**Issue:** Views need to refresh when data changes
**Solution:** LibraryViewModel.loadBooks() called after adds/edits/deletes, triggers @Observable updates

## Success Criteria

- ✅ App uses NavigationSplitView with sidebar navigation
- ✅ AddBookView is full page, not modal
- ✅ BookDetailView is in detail pane, not modal
- ✅ Filters are inline or popover, not full sheet
- ✅ Navigation feels native macOS
- ✅ All existing functionality preserved
- ✅ Better use of screen real estate
- ✅ Smoother user flow without modal layers

## Future Enhancements (Out of Scope)

- Reading Lists (custom collections)
- Favorites section in sidebar
- Recent Books section
- Advanced search with saved searches
- Statistics/Analytics destination
- Column width persistence
- Inspector pane for metadata
