# Sidebar-Based Add Book Navigation Redesign

## Context

The current Add Book interface uses a TabView within AddBookView with three tabs (Search, Manual, ISBN). Users must select the "Add Books" sidebar item, then choose between tabs. The user wants to streamline this by making each option a direct sidebar navigation item under an "Add Book" section, eliminating the tab selector.

Additionally, the Manual entry option should not show BookContentView in the detail column since there's nothing to "look up" - it's just a form.

## Implementation Plan

### 1. Update NavigationDestination Enum

**File:** `tome/ViewModels/NavigationState.swift`

**Changes:**
- Remove the `.addBooks` case
- Add three new cases:
  - `.addBookSearch` - For searching OpenLibrary
  - `.addBookISBN` - For ISBN barcode lookup
  - `.addBookManual` - For manual book entry form

- Update the `==` static function to handle new cases
- Update `hash(into:)` to assign unique hash values for new cases
- Update `displayName` to return "Search", "ISBN", "Manual" respectively
- Update `icon` to return "magnifyingglass", "barcode.viewfinder", "pencil" respectively
- Update `section` property to return `.actions` for all three (or add new section)

**Code Reference (NavigationState.swift:35-85):**
```swift
// Current:
case addBooks

// New:
case addBookSearch, addBookISBN, addBookManual
```

### 2. Update LibrarySidebar

**File:** `tome/Views/Sidebar/LibrarySidebar.swift`

**Changes:**
- Remove the single "Add Books" row from the Actions section (line 24)
- Add a new "Add Book" section (after Library section, before Actions section)
- Add three sidebar rows for the new destinations:
  - "Search" (.addBookSearch) - with magnifyingglass icon
  - "ISBN" (.addBookISBN) - with barcode.viewfinder icon
  - "Manual" (.addBookManual) - with pencil icon

**Code Reference (LibrarySidebar.swift:13-40):**
```swift
// Add new section:
Section("Add Book") {
    sidebarRow(for: .addBookSearch, badge: nil)
    sidebarRow(for: .addBookISBN, badge: nil)
    sidebarRow(for: .addBookManual, badge: nil)
}
```

### 3. Update AddBookView

**File:** `tome/Views/AddBookView.swift`

**Changes:**
- Remove the TabView wrapper and `@State private var selectedTab`
- Extract existing tab views to standalone views:
  - `SearchTabView` content becomes `AddBookSearchView`
  - `ISBNScanTabView` content becomes `AddBookISBNView`
  - `ManualEntryTabView` content becomes `AddBookManualView`
- Create a wrapper that displays the appropriate view based on `navigationState.selectedDestination`
- Ensure each sub-view properly integrates with NavigationState

**Structure:**
```
AddBookView (main entry point)
├── AddBookSearchView (search interface)
├── AddBookISBNView (ISBN scanner)
└── AddBookManualView (manual entry form)
```

### 4. Update NavigationRootView

**File:** `tome/Views/NavigationRootView.swift`

**Changes:**

**a) Update contentForDestination (lines 63-85):**
```swift
// Current:
case .addBooks:
    AddBookContentWrapper { onBookAdded($0) }

// New:
case .addBookSearch:
    AddBookSearchWrapper {
        onBookAdded($0)
    }
case .addBookISBN:
    AddBookISBNWrapper {
        onBookAdded($0)
    }
case .addBookManual:
    AddBookManualWrapper {
        onBookAdded($0)
    }
```

**b) Update sidebar navigation binding (lines 18-24):**
- Update the switch statement to handle new cases instead of `.addBooks`
- Clear selectedBook/searchResult when navigating to any add book destination

**c) Update isLibraryDestination (lines 98-105):**
- Add new cases (`.addBookSearch`, `.addBookISBN`, `.addBookManual`) as non-library destinations

**d) Update detail column BookContentView logic (lines 34-46):**
- Change condition from `navigationState.selectedDestination == .addBooks`
- To: `navigationState.selectedDestination == .addBookSearch || navigationState.selectedDestination == .addBookISBN`
- This ensures Manual entry doesn't show BookContentView

**e) Update detailViewForDestination (lines 109-130):**
- Add cases for `.addBookSearch` and `.addBookISBN` with appropriate empty state messages
- Add case for `.addBookManual` with message about manual entry form

### 5. Create Wrapper Views

**File:** `tome/Views/NavigationRootView.swift` (bottom of file)

Create three new wrapper views similar to `AddBookContentWrapper`:
- `AddBookSearchWrapper` - wraps AddBookSearchView
- `AddBookISBNWrapper` - wraps AddBookISBNView
- `AddBookManualWrapper` - wraps AddBookManualView

Each wrapper passes the `onBookAdded` callback to its respective view.

## Critical Files to Modify

1. **tome/ViewModels/NavigationState.swift** - Add new NavigationDestination cases
2. **tome/Views/Sidebar/LibrarySidebar.swift** - Add sidebar section for Add Book options
3. **tome/Views/AddBookView.swift** - Refactor to remove TabView, extract sub-views
4. **tome/Views/NavigationRootView.swift** - Handle new destinations in content/detail columns

## Existing Code to Reuse

- **SearchTabView** - Already implements search interface with search bar and results list
- **ISBNScanTabView** - Already implements ISBN scanner with auto-lookup
- **ManualEntryTabView** - Already implements manual entry form
- **BookSearchViewModel** - Shared view model for search functionality
- **NavigationState** - Already manages selectedSearchResult for detail view

## Verification

1. Build the project to ensure no compilation errors
2. Run the app and verify sidebar shows "Add Book" section with three options
3. Click "Search" - verify search interface appears with search bar at top, empty list below
4. Click "ISBN" - verify ISBN scanner interface appears
5. Click "Manual" - verify manual entry form appears
6. For Search/ISBN: Select a result and verify BookContentView appears in detail column
7. For Manual: Verify BookContentView does NOT appear in detail column
8. Add a book from each method and verify it appears in library
