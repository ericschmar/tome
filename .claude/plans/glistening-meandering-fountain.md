# Copy Count Feature Implementation Plan

## Context
Users want to track multiple copies of books in their library. This feature will add a `copyCount` property to books, allowing users to specify that they own more than one copy of the same book (e.g., for classroom sets, book clubs, or collector's editions).

## Requirements
- Add `copyCount` property to Book model (default: 1)
- Allow editing copy count in Add Book and Edit Book forms
- Display copy count in Book detail view
- Use hybrid UI (textfield + stepper) for input
- Show copy count in detail view only (not in list/grid)
- Always display count, even when it's 1

## Implementation Plan

### Step 1: Update Book Data Model
**File**: `Tome/Models/Book.swift`

**Add property** (after line 17, after `pageCount`):
```swift
var copyCount: Int = 1
```

**Update initializer** (add parameter to init, line 30-51):
- Add `copyCount: Int = 1` parameter
- Add `self.copyCount = copyCount` in init body (after line 62)

**Migration**: SwiftData will automatically apply default value of 1 to all existing books when the schema changes.

---

### Step 2: Create Hybrid Copy Count Input Component
**File**: `Tome/Views/CopyCountInputView.swift` (new file)

Create a reusable component combining a TextField with a Stepper:
```swift
import SwiftUI

struct CopyCountInputView: View {
    @Binding var copyCount: String
    @State private var stepperValue: Int

    init(copyCount: Binding<String>) {
        self._copyCount = copyCount
        self._stepperValue = State(initialValue: Int(copyCount.wrappedValue) ?? 1)
    }

    var body: some View {
        HStack {
            TextField("Copies", text: $copyCount)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .onChange(of: copyCount) { _, newValue in
                    if let value = Int(newValue), value > 0 {
                        stepperValue = value
                    }
                }

            Stepper("", value: $stepperValue, in: 1...999)
                .labelsHidden()
                .onChange(of: stepperValue) { _, newValue in
                    copyCount = "\(newValue)"
                }
        }
    }
}
```

---

### Step 3: Update EditBookView
**File**: `Tome/Views/EditBookView.swift`

**Add state variable** (after line 17):
```swift
@State private var copyCount: String
```

**Initialize in init** (after line 29):
```swift
_copyCount = State(initialValue: book.copyCount.description)
```

**Replace Year/Pages HStack** (lines 71-74) with:
```swift
HStack {
    TextField("Year", text: $year)
    TextField("Pages", text: $pageCount)
    CopyCountInputView(copyCount: $copyCount)
        .frame(maxWidth: 80)
}
```

**Update saveChanges()** (after line 149, where pageCount is saved):
```swift
book.copyCount = Int(copyCount) ?? 1
```

---

### Step 4: Update AddBookView (Manual Entry)
**File**: `Tome/Views/AddBookView.swift`

**Add state variable** (after line 243, where pageCount is):
```swift
@State private var copyCount = "1"
```

**Add to FocusState enum** (line 697, add to Field enum):
```swift
case copyCount
```

**Add to iOS layout** (around line 390, after Pages field):
```swift
VStack(alignment: .leading, spacing: 4) {
    Label("Copies", systemImage: "doc.on.doc")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    CopyCountInputView(copyCount: $copyCount)
        .focused($focusedField, equals: .copyCount)
}
```

**Add to macOS layout** (around line 355, add to HStack with Year/Pages):
```swift
CopyCountInputView(copyCount: $copyCount)
    .frame(maxWidth: 80)
```

**Update addManualBook()** (line 665, after pageCount):
```swift
copyCount: Int(copyCount) ?? 1,
```

**Update isFormEmpty** (line 650, add check):
```swift
copyCount.isEmpty
```

**Update clearAllFields()** (after line 687):
```swift
copyCount = "1"
```

---

### Step 5: Update BookContentView
**File**: `Tome/Views/BookContentView.swift`

**Add display in metadata section** (after line 223, after Pages GridRow):
```swift
// Copy count
GridRow(alignment: .firstTextBaseline) {
    Text("Copies")
        .gridColumnAlignment(.leading)
        .frame(width: 90, alignment: .leading)
        .font(.system(size: 13, weight: .medium, design: .default))
        .foregroundStyle(.secondary)

    Text(copyCountDisplay)
        .font(.system(size: 13, weight: .regular, design: .default))
        .foregroundStyle(.primary)
        .textSelection(.enabled)
}
```

**Add computed property** (around line 486):
```swift
private var copyCountDisplay: String {
    let count = source.copyCount ?? 1
    return count == 1 ? "1 copy" : "\(count) copies"
}
```

---

### Step 6: Update BookContentSource
**File**: `Tome/Models/BookContentSource.swift`

**Add computed property** (around line 53):
```swift
var copyCount: Int? {
    switch self {
    case .library(let book): return book.copyCount
    case .search: return nil
    }
}
```

---

## Testing Checklist

### Data Model
- [ ] Launch app - verify no crash with schema change
- [ ] Check existing book - copyCount should default to 1
- [ ] Verify CloudKit sync works (if available)

### Add Book Flow
- [ ] Add book manually without changing copy count → saves as 1
- [ ] Add book with copy count of 3 → saves correctly
- [ ] Try entering 0 → defaults to 1
- [ ] Try entering negative number → defaults to 1
- [ ] Try entering text → defaults to 1
- [ ] Test stepper increment/decrement
- [ ] Test typing in text field
- [ ] Verify hybrid: stepper updates textfield, textfield updates stepper

### Edit Book Flow
- [ ] Edit existing book - verify field shows current count
- [ ] Change count from 1 to 5 → saves correctly
- [ ] Change count from 5 to 1 → saves correctly
- [ ] Test stepper functionality in edit mode

### Display
- [ ] View book with 1 copy → shows "1 copy"
- [ ] View book with 2 copies → shows "2 copies"
- [ ] View book with 10 copies → shows "10 copies"
- [ ] Verify text is selectable (textSelection works)

### Search Results
- [ ] Search result should not show copy count (returns nil)
- [ ] After adding search result to library, it should have copy count of 1

---

## Summary

This implementation:
- ✅ Adds `copyCount` property with default value of 1
- ✅ Uses hybrid UI (textfield + stepper) for easy input
- ✅ Displays in detail view only (not list/grid)
- ✅ Always shows count with proper singular/plural ("1 copy" vs "2 copies")
- ✅ Validates input (min: 1, max: 999)
- ✅ Handles migration automatically via SwiftData default value
- ✅ Maintains CloudKit sync compatibility

## Critical Files

- `Tome/Models/Book.swift` - Core model: add copyCount property
- `Tome/Views/CopyCountInputView.swift` - NEW: Hybrid input component
- `Tome/Views/EditBookView.swift` - Add copy count field to edit form
- `Tome/Views/AddBookView.swift` - Add copy count field to add form
- `Tome/Views/BookContentView.swift` - Display copy count in detail view
- `Tome/Models/BookContentSource.swift` - Expose copyCount for display
