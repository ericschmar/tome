import Foundation
internal import CloudKit
import AppKit

/// Service to fetch and manage CloudKit account information
@MainActor
@Observable
class CloudKitAccountService {
    static let shared = CloudKitAccountService()
    
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var userDisplayName: String?
    var userPhoto: NSImage?
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
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
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
                userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
                isLoading = false
                return
            }
            
            print("✅ CloudKit account is available, attempting to fetch user info...")
            isCloudKitEnabled = true
            
            // Fetch user record ID - this requires the "iCloud" capability
            let userRecordID = try await container.userRecordID()
            print("✅ Got user record ID: \(userRecordID.recordName)")
            
            // Try to fetch user identity - this may fail if user hasn't enabled discoverability
            // This is optional and shouldn't prevent CloudKit from working
            do {
                let userIdentity = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKUserIdentity, Error>) in
                    container.discoverUserIdentity(withUserRecordID: userRecordID) { identity, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let identity = identity {
                            continuation.resume(returning: identity)
                        } else {
                            continuation.resume(throwing: CKError(.unknownItem))
                        }
                    }
                }
                
                // Extract display name
                if let givenName = userIdentity.nameComponents?.givenName,
                   let familyName = userIdentity.nameComponents?.familyName {
                    userDisplayName = "\(givenName) \(familyName)"
                } else {
                    userDisplayName = userIdentity.nameComponents?.givenName ?? "iCloud User"
                }
                
                print("✅ Successfully fetched user info: \(userDisplayName ?? "unknown")")
                
                // Fetch user photo if available
                if userIdentity.contactIdentifiers.first != nil {
                    await fetchUserPhotoFromContacts()
                }
            } catch let identityError as CKError where identityError.code == .notAuthenticated {
                // User hasn't enabled "Allow people to look me up by email" in iCloud settings
                // This is not a critical error - CloudKit still works, we just can't get their name
                print("ℹ️ CloudKitAccountService: User identity not discoverable (user privacy setting)")
                print("   CloudKit is still enabled and will work for syncing data")
                
                // Fall back to system user name instead
                userDisplayName = NSFullUserName().isEmpty ? "iCloud User" : NSFullUserName()
                userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
                
                print("   Using system user name: \(userDisplayName ?? "unknown")")
            } catch {
                // Other errors fetching identity - also not critical
                print("⚠️ CloudKitAccountService: Could not fetch user identity - \(error.localizedDescription)")
                
                // Fall back to system user name
                userDisplayName = NSFullUserName().isEmpty ? "iCloud User" : NSFullUserName()
                userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
            }
            
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
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
            isLoading = false
        } catch {
            // Non-CloudKit errors
            self.error = error
            isCloudKitEnabled = false
            accountStatus = .noAccount
            userDisplayName = "Local User"
            userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
            isLoading = false
            print("❌ CloudKitAccountService: Unexpected error - \(error.localizedDescription)")
        }
    }
    
    /// Attempt to fetch user photo from system
    private func fetchUserPhotoFromContacts() async {
        // For now, we'll use the default user image
        // In a production app, you might want to use Contacts framework
        // or let the user set a custom profile photo
        userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: "User")
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
