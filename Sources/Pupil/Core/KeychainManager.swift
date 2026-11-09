//
//  KeychainManager.swift
//  Pupil
//
//  Salted cryptographic SHA-256 PIN store and Touch ID (LocalAuthentication) helper.
//  Zero plaintext storage; fast, non-blocking, and never triggers legacy Keychain password prompts.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

public enum KeychainError: LocalizedError {
    case invalidPinFormat
    case itemNotFound
    case authenticationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidPinFormat:
            return "PIN must be 4 to 8 digits."
        case .itemNotFound:
            return "No PIN is enrolled yet."
        case .authenticationFailed:
            return "Authentication was cancelled or failed."
        }
    }
}

public struct StoredPinRecord: Codable {
    public let saltHex: String
    public let digestHex: String

    public init(saltHex: String, digestHex: String) {
        self.saltHex = saltHex
        self.digestHex = digestHex
    }
}

public enum KeychainManager {
    nonisolated public static let storeKey = "pupil.saltedPinRecord"

    nonisolated public static func isValidPinFormat(_ pin: String) -> Bool {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...8).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }

    nonisolated public static var hasEnrolledPin: Bool {
        loadStoredRecord() != nil
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
        saveStoredRecord(data)
    }

    nonisolated public static func verifyPin(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPinFormat(trimmed) else { return false }

        guard let record = loadStoredRecord() else {
            return false
        }
        let candidateDigest = hashPin(trimmed, saltHex: record.saltHex)
        return constantTimeEqual(candidateDigest, record.digestHex)
    }

    nonisolated public static func clearEnrolledPin() {
        UserDefaults.standard.removeObject(forKey: storeKey)
        UserDefaults.standard.removeObject(forKey: "pupil.fallbackPinRecord")
        if let fileURL = recordFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
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

    /// Authenticates the Mac owner via macOS System Login Password, Touch ID, or Apple Watch (for PIN recovery).
    nonisolated public static func authenticateDeviceOwner(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
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

    nonisolated private static var recordFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Pupil", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }
        return dir.appendingPathComponent("pin.record")
    }

    nonisolated private static func loadStoredRecord() -> StoredPinRecord? {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let record = try? JSONDecoder().decode(StoredPinRecord.self, from: data) {
            return record
        }
        if let data = UserDefaults.standard.data(forKey: "pupil.fallbackPinRecord"),
           let record = try? JSONDecoder().decode(StoredPinRecord.self, from: data) {
            return record
        }
        if let fileURL = recordFileURL,
           let data = try? Data(contentsOf: fileURL),
           let record = try? JSONDecoder().decode(StoredPinRecord.self, from: data) {
            return record
        }
        return nil
    }

    nonisolated private static func saveStoredRecord(_ data: Data) {
        UserDefaults.standard.set(data, forKey: storeKey)
        UserDefaults.standard.set(data, forKey: "pupil.fallbackPinRecord")
        if let fileURL = recordFileURL {
            try? data.write(to: fileURL, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        }
    }
}
