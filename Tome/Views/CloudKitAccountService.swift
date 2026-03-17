import Foundation
import OSLog
internal import CloudKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "com.ericschmar.tome", category: "cloudkit-account")

/// Service to fetch and manage CloudKit account information
@MainActor
@Observable
class CloudKitAccountService {
    static let shared = CloudKitAccountService()

    var accountStatus: CKAccountStatus = .couldNotDetermine
    var userDisplayName: String?
    var userRecordIDString: String?
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
        let container = CKContainer.default()
        logger.debug("CloudKit container ID: \(container.containerIdentifier ?? "nil")")
        Task {
            await fetchAccountInfo()
        }
    }

    /// Fetch the current iCloud account status and user information
    func fetchAccountInfo() async {
        isLoading = true
        error = nil

        if container == nil {
            container = CKContainer.default()
        }

        guard let container = container else {
            self.error = NSError(
                domain: "CloudKitAccountService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cloud Not Enabled"]
            )
            isCloudKitEnabled = false
            accountStatus = .noAccount
            userDisplayName = "Local User"
            setDefaultPhoto()
            isLoading = false
            return
        }

        do {
            accountStatus = try await container.accountStatus()
            logger.info("Account status: \(self.accountStatus.rawValue)")

            guard accountStatus == .available else {
                switch accountStatus {
                case .noAccount:
                    logger.info("User is not signed into iCloud")
                case .restricted:
                    logger.warning("iCloud access is restricted")
                case .temporarilyUnavailable:
                    logger.warning("iCloud is temporarily unavailable")
                default:
                    break
                }
                isCloudKitEnabled = false
                userDisplayName = "Local User"
                setDefaultPhoto()
                isLoading = false
                return
            }

            isCloudKitEnabled = true

            let userRecordID = try await container.userRecordID()
            userRecordIDString = userRecordID.recordName
            logger.info("User record ID: \(userRecordID.recordName)")

            userDisplayName = NSFullUserName().isEmpty ? "iCloud User" : NSFullUserName()
            logger.debug("Display name: \(self.userDisplayName ?? "unknown")")

            setDefaultPhoto()
            isLoading = false
        } catch let ckError as CKError {
            switch ckError.code {
            case .notAuthenticated:
                logger.error("Not authenticated with iCloud — check entitlements")
            case .networkUnavailable, .networkFailure:
                logger.error("Network issue: \(ckError.localizedDescription)")
            case .permissionFailure:
                logger.error("Permission denied for iCloud access")
            case .badContainer:
                logger.error("Bad container configuration — check container identifier")
            default:
                logger.error("CKError \(ckError.code.rawValue): \(ckError.localizedDescription) — \(ckError.errorUserInfo)")
            }

            self.error = ckError
            isCloudKitEnabled = false
            if accountStatus == .couldNotDetermine {
                accountStatus = .noAccount
            }
            userDisplayName = "Local User"
            setDefaultPhoto()
            isLoading = false
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            self.error = error
            isCloudKitEnabled = false
            accountStatus = .noAccount
            userDisplayName = "Local User"
            setDefaultPhoto()
            isLoading = false
        }
    }

    private func setDefaultPhoto() {
        #if canImport(AppKit)
        userPhoto = NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)
        #elseif canImport(UIKit)
        userPhoto = UIImage(systemName: "person.circle.fill")
        #endif
    }

    var displayName: String {
        userDisplayName ?? "Local User"
    }

    var isAccountAvailable: Bool {
        isCloudKitEnabled && accountStatus == .available
    }

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
