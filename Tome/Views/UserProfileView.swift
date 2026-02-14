import SwiftUI
internal import CloudKit

/// User profile view for the sidebar footer
struct UserProfileView: View {
    @State private var accountService = CloudKitAccountService.shared
    @State private var showingMenu = false
    @State private var showingSettings = false
    
    var body: some View {
        Button {
            showingMenu.toggle()
        } label: {
            HStack(spacing: 10) {
                // User photo
                userPhotoView
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                // User name
                if accountService.isAccountAvailable {
                    Text(accountService.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Not Signed In")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron down
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showingMenu ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: showingMenu)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingMenu, arrowEdge: .top) {
            userMenuPopover
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .task {
            if accountService.userDisplayName == nil && !accountService.isLoading {
                await accountService.fetchAccountInfo()
            }
        }
    }
    
    @ViewBuilder
    private var userPhotoView: some View {
        if let photo = accountService.userPhoto {
            Image(platformImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.gray)
        }
    }
    
    private var userMenuPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    userPhotoView
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if accountService.isAccountAvailable {
                            Text(accountService.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Text("iCloud Account")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not Signed In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            accountStatusText
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            
            Divider()
            
            // Menu options
            VStack(alignment: .leading, spacing: 0) {
                menuButton(
                    icon: "gearshape",
                    title: "Settings",
                    action: openSettings
                )
            }
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
    
    @ViewBuilder
    private var accountStatusText: some View {
        switch accountService.accountStatus {
        case .available:
            Text("Available")
        case .noAccount:
            Text("No iCloud account")
        case .restricted:
            Text("Restricted")
        case .couldNotDetermine:
            Text("Status unknown")
        case .temporarilyUnavailable:
            Text("Temporarily unavailable")
        @unknown default:
            Text("Unknown status")
        }
    }
    
    private func menuButton(
        icon: String,
        title: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDisabled ? .tertiary : .secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(isDisabled ? .tertiary : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    
    private func openSettings() {
        showingMenu = false
        showingSettings = true
    }
}

#Preview {
    VStack {
        Spacer()
        UserProfileView()
            .padding()
    }
    .frame(width: 240)
}
