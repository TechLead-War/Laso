import AuthenticationServices
import CryptoKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Handles Sign In with Apple end-to-end:
/// 1. Generates a cryptographic nonce (Apple security requirement).
/// 2. Drives `ASAuthorizationController` to show the Apple sign-in sheet.
/// 3. Receives the Apple ID token and exchanges it for a Firebase OAuth credential.
/// 4. If a Firebase anonymous user is currently signed in, the anonymous account
///    is *linked* (UID preserved, all local + Firestore data intact). If link
///    fails because the Apple ID is already linked to a different Firebase user,
///    falls back to a clean `signIn` so the user gets their existing account.
/// 5. Returns the display name when Apple provides it (Apple only returns the
///    full name on FIRST sign-in, never again) so the caller can store it.
@MainActor
public final class AppleAuthService: NSObject {

    public enum AppleAuthError: Error {
        case unableToGetIdToken
        case userCancelled
        case authorizationFailed(Error)
        case firebaseLinkFailed(Error)
        case firebaseSignInFailed(Error)
    }

    public static let shared = AppleAuthService()
    private override init() { super.init() }

    private var currentNonce: String?
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    public struct AppleSignInResult {
        public let fullName: PersonNameComponents?
    }

    /// Begins the Sign In with Apple flow. Returns the Firebase user info on success.
    public func signIn() async throws -> AppleSignInResult {
        let rawNonce = Self.makeRandomNonce()
        currentNonce = rawNonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AppleSignInResult, Error>) in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Firebase exchange

    private func exchangeWithFirebase(idTokenString: String, rawNonce: String, fullName: PersonNameComponents?) async -> Result<AppleSignInResult, AppleAuthError> {
        #if canImport(FirebaseAuth)
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: rawNonce
        )

        // Prefer linking the existing anonymous user so all local + server data
        // stays attached to the same Firebase UID.
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                _ = try await currentUser.link(with: credential)
                return .success(.init(fullName: fullName))
            } catch let nsError as NSError {
                // If Apple ID is already linked to a different Firebase user,
                // fall back to a clean sign-in (existing account takes over).
                let credentialAlreadyInUse = AuthErrorCode.credentialAlreadyInUse.rawValue
                if nsError.code == credentialAlreadyInUse,
                   let existingCredential = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                    return await firebaseSignIn(credential: existingCredential, fullName: fullName)
                }
                return .failure(.firebaseLinkFailed(nsError))
            }
        }

        // No anonymous user — sign in fresh.
        return await firebaseSignIn(credential: credential, fullName: fullName)
        #else
        return .failure(.firebaseLinkFailed(NSError(domain: "AppleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "FirebaseAuth not linked"])))
        #endif
    }

    #if canImport(FirebaseAuth)
    private func firebaseSignIn(credential: AuthCredential, fullName: PersonNameComponents?) async -> Result<AppleSignInResult, AppleAuthError> {
        do {
            _ = try await Auth.auth().signIn(with: credential)
            return .success(.init(fullName: fullName))
        } catch {
            return .failure(.firebaseSignInFailed(error))
        }
    }
    #endif

    // MARK: - Nonce helpers

    private static func makeRandomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte) % charset.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let rawNonce = currentNonce,
            let idTokenData = credential.identityToken,
            let idTokenString = String(data: idTokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AppleAuthError.unableToGetIdToken)
            cleanup()
            return
        }

        let fullName = credential.fullName
        let cont = continuation
        Task { [weak self] in
            guard let self else { return }
            let exchange = await self.exchangeWithFirebase(
                idTokenString: idTokenString,
                rawNonce: rawNonce,
                fullName: fullName
            )
            switch exchange {
            case .success(let result):
                cont?.resume(returning: result)
            case .failure(let error):
                cont?.resume(throwing: error)
            }
            self.cleanup()
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            continuation?.resume(throwing: AppleAuthError.userCancelled)
        } else {
            continuation?.resume(throwing: AppleAuthError.authorizationFailed(error))
        }
        cleanup()
    }

    private func cleanup() {
        currentNonce = nil
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Foreground active scene's first window — works for SwiftUI lifecycle apps.
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let window = scenes.first?.windows.first(where: { $0.isKeyWindow }) ?? scenes.first?.windows.first {
            return window
        }
        // Fallback: any UIWindow present.
        return UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first }
            .first ?? UIWindow()
    }
}
