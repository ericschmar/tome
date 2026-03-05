import Foundation
internal import CloudKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Service to fetch and manage CloudKit account information
@MainActor
@Observable
class CloudKitAccountService {
    static let shared = CloudKitAccountService()
    
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var userDisplayName: String?
    #if canImport(AppKit)
    var userPhoto: NSImage?
    #elseif canImport(UIKit)
    var userPhoto: UIImage?
    #endif
    var isLoading = false
    var error: Error?
    var isCloudKitEnabled = false
    
    private var container: CKContainer?
    
    private init() {
        // For personal development teams, CloudKit won't work
        // This will be nil if entitlements aren't configured
        
        // Debug: Print container identifier
        #if DEBUG
        let container = CKContainer.default()
        print("🔍 CloudKit Container ID: \(container.containerIdentifier ?? "nil")")
        #endif
        Task {
            await fetchAccountInfo()
        }
    }
    
    /// Fetch the current iCloud account status and user information
    func fetchAccountInfo() async {
        isLoading = true
        error = nil
        
        // Try to initialize CloudKit container lazily
        // This will fail for personal development teams without entitlements
        if container == nil {
            container = CKContainer.default()
        }
        
        guard let container = container else {
            // CloudKit not available - set a friendly error
            self.error = NSError(
                domain: "CloudKitAccountService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cloud Not Enabled"]
            )
            isCloudKitEnabled = false
            accountStatus = .noAccount
            userDisplayName = "Local User"
            #if canImport(AppKit)
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
            #elseif canImport(UIKit)
            userPhoto = UIImage(systemName: "person.circle.fill")
            #endif
            isLoading = false
            return
        }
        
        do {
            // Check account status first - this is a simple call that should work
            accountStatus = try await container.accountStatus()
            print("🔍 CloudKit Account Status: \(accountStatus.rawValue)")
            
            guard accountStatus == .available else {
                // Not an error condition - user just isn't signed into iCloud
                if accountStatus == .noAccount {
                    print("ℹ️ CloudKitAccountService: User is not signed into iCloud")
                } else if accountStatus == .restricted {
                    print("⚠️ CloudKitAccountService: iCloud access is restricted")
                } else if accountStatus == .temporarilyUnavailable {
                    print("⚠️ CloudKitAccountService: iCloud is temporarily unavailable")
                }
                isCloudKitEnabled = false
                userDisplayName = "Local User"
                #if canImport(AppKit)
                userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
                #elseif canImport(UIKit)
                userPhoto = UIImage(systemName: "person.circle.fill")
                #endif
                isLoading = false
                return
            }
            
            print("✅ CloudKit account is available")
            isCloudKitEnabled = true
            
            // Fetch user record ID to verify CloudKit access
            let userRecordID = try await container.userRecordID()
            print("✅ Got user record ID: \(userRecordID.recordName)")
            
            // Use system user name for display
            // Note: The discoverUserIdentity API was deprecated in macOS 14.0 and is no longer
            // supported. For displaying the current user's name, we use the system user name.
            // User identity discovery was primarily for finding other users for sharing purposes.
            userDisplayName = NSFullUserName().isEmpty ? "iCloud User" : NSFullUserName()
            print("✅ Using system user name: \(userDisplayName ?? "unknown")")
            
            // Set default user photo
            #if canImport(AppKit)
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
            #elseif canImport(UIKit)
            userPhoto = UIImage(systemName: "person.circle.fill")
            #endif
            
            isLoading = false
        } catch let ckError as CKError {
            // Handle specific CloudKit errors
            switch ckError.code {
            case .notAuthenticated:
                print("ℹ️ CloudKitAccountService: User is not authenticated with iCloud")
                print("   This usually means CloudKit container is not properly configured in entitlements")
            case .networkUnavailable, .networkFailure:
                print("⚠️ CloudKitAccountService: Network issue - \(ckError.localizedDescription)")
            case .permissionFailure:
                print("⚠️ CloudKitAccountService: Permission denied for iCloud access")
                print("   Check that the app has iCloud capability enabled")
            case .badContainer:
                print("❌ CloudKitAccountService: Bad container configuration")
                print("   The CloudKit container identifier may be incorrect or not configured")
            default:
                print("❌ CloudKitAccountService: CloudKit error - \(ckError.localizedDescription)")
                print("   Error code: \(ckError.code.rawValue)")
                print("   User info: \(ckError.errorUserInfo)")
            }
            
            self.error = ckError
            isCloudKitEnabled = false
            // Try to preserve account status if we already have it, otherwise default to noAccount
            if accountStatus == .couldNotDetermine {
                accountStatus = .noAccount
            }
            userDisplayName = "Local User"
            #if canImport(AppKit)
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
            #elseif canImport(UIKit)
            userPhoto = UIImage(systemName: "person.circle.fill")
            #endif
            isLoading = false
        } catch {
            // Non-CloudKit errors
            self.error = error
            isCloudKitEnabled = false
            accountStatus = .noAccount
            userDisplayName = "Local User"
            #if canImport(AppKit)
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
            #elseif canImport(UIKit)
            userPhoto = UIImage(systemName: "person.circle.fill")
            #endif
            isLoading = false
            print("❌ CloudKitAccountService: Unexpected error - \(error.localizedDescription)")
        }
    }
    
    /// Attempt to fetch user photo from system
    private func fetchUserPhotoFromContacts() async {
        // For now, we'll use the default user image
        // TODO: In a production app, you might want to use Contacts framework
        // or let the user set a custom profile photo
        #if canImport(AppKit)
        userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
        #elseif canImport(UIKit)
        userPhoto = UIImage(systemName: "person.circle.fill")
        #endif
    }
    
    /// Returns a placeholder name if no user name is available
    var displayName: String {
        userDisplayName ?? "Local User"
    }
    
    /// Returns whether the account is available
    var isAccountAvailable: Bool {
        isCloudKitEnabled && accountStatus == .available
    }
    
    /// Returns a user-friendly status message
    var statusMessage: String {
        if !isCloudKitEnabled {
            return "Cloud Not Enabled"
        }
        
        switch accountStatus {
        case .available:
            if userDisplayName == "iCloud User" {
                return "Connected to iCloud (Limited Info)"
            }
            return "Connected to iCloud"
        case .noAccount:
            return "Not signed into iCloud"
        case .restricted:
            return "iCloud restricted"
        case .couldNotDetermine:
            return "Checking iCloud status..."
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        @unknown default:
            return "Unknown status"
        }
    }
}
