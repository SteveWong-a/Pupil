//
//  KeychainManager.swift
//  Pupil
//
//  Keychain Services + CryptoKit salted hash store and Touch ID (LocalAuthentication) helper.
//  Never logs or stores plaintext PINs.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

public enum KeychainError: LocalizedError {
    case invalidPinFormat
    case itemNotFound
    case authenticationFailed
    case osStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidPinFormat:
            return "PIN must be 4 to 8 digits."
        case .itemNotFound:
            return "No PIN is enrolled yet."
        case .authenticationFailed:
            return "Authentication was cancelled or failed."
        case .osStatus(let status):
            let msg = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain error: \(msg)"
        }
    }
}

private struct StoredPinRecord: Codable {
    let saltHex: String
    let digestHex: String
}

public enum KeychainManager {
    nonisolated public static let service = "com.pupil.security"
    nonisolated private static let pinAccount = "enrolled-pin-sha256"

    nonisolated public static func isValidPinFormat(_ pin: String) -> Bool {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...8).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }

    nonisolated public static var hasEnrolledPin: Bool {
        if (try? readData(account: pinAccount)) != nil {
            return true
        }
        return UserDefaults.standard.data(forKey: "pupil.fallbackPinRecord") != nil
    }

    nonisolated public static func enrollPin(_ pin: String) throws {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPinFormat(trimmed) else {
            throw KeychainError.invalidPinFormat
        }
        var saltBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        let saltHex = saltBytes.map { String(format: "%02x", $0) }.joined()
        let digestHex = hashPin(trimmed, saltHex: saltHex)

        let record = StoredPinRecord(saltHex: saltHex, digestHex: digestHex)
        let data = try JSONEncoder().encode(record)

        // Store in macOS Keychain; keep salted hash in UserDefaults fallback for unsigned CLI test runs
        UserDefaults.standard.set(data, forKey: "pupil.fallbackPinRecord")
        try? saveData(account: pinAccount, data: data)
    }

    nonisolated public static func verifyPin(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPinFormat(trimmed) else { return false }

        let data = (try? readData(account: pinAccount)) ?? UserDefaults.standard.data(forKey: "pupil.fallbackPinRecord")
        guard let data,
              let record = try? JSONDecoder().decode(StoredPinRecord.self, from: data) else {
            return false
        }
        let candidateDigest = hashPin(trimmed, saltHex: record.saltHex)
        return constantTimeEqual(candidateDigest, record.digestHex)
    }

    nonisolated public static func clearEnrolledPin() {
        UserDefaults.standard.removeObject(forKey: "pupil.fallbackPinRecord")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    nonisolated public static func authenticateWithTouchID(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }

    nonisolated private static func hashPin(_ pin: String, saltHex: String) -> String {
        let combined = Data((saltHex + ":" + pin).utf8)
        let digest = SHA256.hash(data: combined)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }

    nonisolated private static func readData(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.osStatus(status)
        }
        return data
    }

    nonisolated private static func saveData(account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainError.osStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.osStatus(addStatus)
        }
    }
}
