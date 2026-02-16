# Add Search Cancel, Timeout, and Improved Error Handling

## Context

When adding multiple books (18-20+), the OpenLibrary search API sometimes hangs indefinitely, showing a spinner that never resolves. Users need a way to cancel stuck searches and get proper timeout/error feedback.

This plan adds:
1. **Cancel button** - Users can stop in-progress searches
2. **15-second client-side timeout** - Searches fail fast instead of hanging
3. **Improved error handling** - Loading indicators always clear on errors with user-friendly messages

## Files to Modify

### Primary Files
- `Tome/ViewModels/BookSearchViewModel.swift` - Add task tracking, cancel, and timeout
- `Tome/Views/Sidebar/BulkAddBooksView.swift` - Add cancel button to bulk add search
- `Tome/Views/AddBookView.swift` - Add cancel button to regular search
- `Tome/Models/OpenLibraryModels.swift` - Add timeout error type

## Implementation Plan

### 1. Add Timeout Error Type (`OpenLibraryModels.swift`)

Add a new case to the `OpenLibraryError` enum:

```swift
enum OpenLibraryError: Error, LocalizedError {
    // ... existing cases ...
    case timeout
}
```

Add error description:

```swift
case .timeout:
    return "Request timed out. Please try again."
```

### 2. Add Task Cancellation and Timeout to `BookSearchViewModel`

**Add properties:**
- `private var searchTask: Task<Void, Never>?` - Track active search task
- `func cancelSearch()` - Cancel the active task

**Add timeout wrapper:**
- Create a helper method `withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T`
- Use `Task.sleep()` combined with `Task.withGroup` to race between the operation and timeout

**Modify existing methods:**
- `searchBooks()` - Wrap service call in timeout, store task in `searchTask`, set `isLoading = false` in cancellation handler
- `loadMoreResults()` - Same pattern
- `lookupByISBN()` - Same pattern
- `fetchBookDetails()` - Same pattern

**Implementation pattern:**
```swift
func searchBooks() async {
    guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
        searchResults = []
        hasPerformedSearch = false
        return
    }

    isLoading = true
    errorMessage = nil
    currentOffset = 0

    searchTask = Task {
        do {
            let results = try await withTimeout(15.0) {
                try await service.searchBooksDebounced(query: searchQuery)
            }
            guard !Task.isCancelled else { return }
            searchResults = results
            hasMoreResults = results.count == limit
            hasPerformedSearch = true
        } catch {
            guard !Task.isCancelled else { return }
            self.errorMessage = error.localizedDescription
            searchResults = []
            hasPerformedSearch = true
        }
        isLoading = false
    }

    await searchTask?.value
}

func cancelSearch() {
    searchTask?.cancel()
    searchTask = nil
    isLoading = false
}
```

### 3. Add Cancel Button to `AddBookView`

In the loading state view (around line 107-112), add a cancel button below the spinner:

```swift
if viewModel.isLoading {
    VStack(spacing: 12) {
        ProgressView(isISBNQuery ? "Looking up ISBN..." : "Searching...")
            .padding(.top, 40)

        Button("Cancel Search") {
            viewModel.cancelSearch()
        }
        .buttonStyle(.bordered)

        Spacer()
    }
}
```

### 4. Update `BulkAddViewModel` with Same Pattern

**Add properties:**
- `private var searchTask: Task<Void, Never>?`
- `func cancelSearch()`

**Modify `performSearch()`:**
- Same timeout and task tracking pattern as `BookSearchViewModel`

**Add cancel button to UI (line 32-34):**
```swift
if viewModel.isSearching {
    VStack(spacing: 12) {
        ProgressView(viewModel.isISBNQuery ? "Looking up ISBN..." : "Searching...")
            .frame(height: 200)

        Button("Cancel Search") {
            viewModel.cancelSearch()
        }
        .buttonStyle(.bordered)
    }
    .frame(height: 240)
}
```

### 5. Timeout Helper Implementation

Add this helper to both ViewModels:

```swift
private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }

        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw OpenLibraryError.timeout
        }

        // Return the first one to complete
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## Verification

1. **Test cancel button:**
   - Start a search
   - Click "Cancel Search" button
   - Verify spinner disappears immediately
   - Verify no error message appears (clean cancellation)

2. **Test timeout:**
   - Simulate slow network (use Network Link Conditioner or modify timeout to 1 second for testing)
   - Start a search
   - After 15 seconds, verify:
     - Spinner stops
     - Error message appears: "Request timed out. Please try again."

3. **Test error handling:**
   - Disconnect network and search
   - Verify spinner stops
   - Verify error message appears

4. **Test normal flow still works:**
   - Search for books
   - Verify results load normally
   - Verify load more results works

5. **Test both screens:**
   - Test AddBookView (single book search)
   - Test BulkAddBooksView (bulk add screen)
