import Photos
import UIKit

/// Optional copy of Daily Mirror photos into the system Photos app.
///
/// The private archive in `MirrorPhotoStore` is deliberately excluded from every
/// backup, which means deleting Laso deletes it. This is the one escape hatch
/// from that, and it is off until the user turns it on: the photo goes to their
/// camera roll, where their own iCloud Photos backup takes over.
///
/// Add-only authorisation is used on purpose. Laso can hand a photo to Photos
/// and nothing else: it can never read, list, or delete what is already there,
/// so turning this on does not widen what the app can see.
enum MirrorPhotoLibrary {

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppKeys.Mirror.saveToPhotos) }
        set { UserDefaults.standard.set(newValue, forKey: AppKeys.Mirror.saveToPhotos) }
    }

    /// True once the user has allowed Laso to add photos. Asks the first time.
    @discardableResult
    static func requestAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .authorized || status == .limited { return true }
        guard status == .notDetermined else { return false }
        let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return granted == .authorized || granted == .limited
    }

    /// Adds one finished photo. Returns false on a denied library or a failed
    /// write, so the caller can say so instead of silently doing nothing.
    @discardableResult
    static func save(_ image: UIImage) async -> Bool {
        guard await requestAccess() else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }

    /// Adds a whole archive in one pass and reports how many landed.
    ///
    /// Takes file URLs, not images: a years-long archive loaded into memory as
    /// `UIImage`s at once is how an export like this runs a phone out of RAM.
    /// Handing Photos the original JPEG also skips a decode and re-encode, so
    /// the copy is byte for byte what the archive holds. One change block means
    /// one transaction rather than N half-finished ones.
    static func saveAll(_ urls: [URL]) async -> Int {
        guard !urls.isEmpty, await requestAccess() else { return 0 }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in urls {
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = false
                    PHAssetCreationRequest.forAsset()
                        .addResource(with: .photo, fileURL: url, options: options)
                }
            }
            return urls.count
        } catch {
            return 0
        }
    }
}
