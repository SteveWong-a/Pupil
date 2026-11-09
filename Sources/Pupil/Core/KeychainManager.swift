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
    nonisolated public static let totpStoreKey = "pupil.totpSecretBase32"

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

    /// Authenticates the Mac owner via Touch ID, Apple Watch, or macOS System Login Password (for PIN recovery).
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

    // MARK: - Phone 2FA Authenticator (RFC 6238 TOTP)

    nonisolated public static func ensureTOTPSecret() -> String {
        if let existing = loadTOTPSecret(), !existing.isEmpty {
            return existing
        }
        return regenerateTOTPSecret()
    }

    @discardableResult
    nonisolated public static func regenerateTOTPSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 20)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let secret = base32Encode(Data(bytes))
        saveTOTPSecret(secret)
        return secret
    }

    nonisolated public static func totpProvisioningURI(secretBase32: String? = nil) -> String {
        let secret = secretBase32 ?? ensureTOTPSecret()
        return "otpauth://totp/Pupil:Mac%20Security?secret=\(secret)&issuer=Pupil&algorithm=SHA1&digits=6&period=30"
    }

    nonisolated public static func currentTOTPCode(at date: Date = Date(), secretBase32: String? = nil) -> String? {
        let secret = secretBase32 ?? ensureTOTPSecret()
        guard let secretData = base32Decode(secret), !secretData.isEmpty else { return nil }
        let counter = UInt64(max(0, date.timeIntervalSince1970)) / 30
        return generateTOTP(secretData: secretData, counter: counter)
    }

    nonisolated public static func verifyTOTPCode(_ candidate: String, at date: Date = Date(), secretBase32: String? = nil) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, trimmed.allSatisfy(\.isNumber) else { return false }
        let secret = secretBase32 ?? ensureTOTPSecret()
        guard let secretData = base32Decode(secret), !secretData.isEmpty else { return false }

        let baseCounter = Int64(max(0, date.timeIntervalSince1970)) / 30
        for offset in -1...1 {
            let step = baseCounter + Int64(offset)
            guard step >= 0 else { continue }
            let expected = generateTOTP(secretData: secretData, counter: UInt64(step))
            if constantTimeEqual(trimmed, expected) {
                return true
            }
        }
        return false
    }

    nonisolated private static func generateTOTP(secretData: Data, counter: UInt64) -> String {
        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: MemoryLayout<UInt64>.size)
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0f)
        let truncatedHash =
            (UInt32(hmacBytes[offset] & 0x7f) << 24) |
            (UInt32(hmacBytes[offset + 1]) << 16) |
            (UInt32(hmacBytes[offset + 2]) << 8) |
            UInt32(hmacBytes[offset + 3])
        let code = truncatedHash % 1_000_000
        return String(format: "%06u", code)
    }

    nonisolated private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    nonisolated private static func base32Encode(_ data: Data) -> String {
        var result = ""
        var buffer = 0
        var bitsLeft = 0
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                let index = (buffer >> (bitsLeft - 5)) & 0x1f
                result.append(base32Alphabet[index])
                bitsLeft -= 5
            }
        }
        if bitsLeft > 0 {
            let index = (buffer << (5 - bitsLeft)) & 0x1f
            result.append(base32Alphabet[index])
        }
        return result
    }

    nonisolated private static func base32Decode(_ string: String) -> Data? {
        let cleaned = string.uppercased().filter { $0 != "=" && $0 != " " && $0 != "-" }
        var buffer = 0
        var bitsLeft = 0
        var bytes = [UInt8]()
        for char in cleaned {
            guard let val = base32Alphabet.firstIndex(of: char) else { return nil }
            buffer = (buffer << 5) | val
            bitsLeft += 5
            if bitsLeft >= 8 {
                let byte = UInt8((buffer >> (bitsLeft - 8)) & 0xff)
                bytes.append(byte)
                bitsLeft -= 8
            }
        }
        return Data(bytes)
    }

    nonisolated private static var totpFileURL: URL? {
        recordFileURL?.deletingLastPathComponent().appendingPathComponent("totp.secret")
    }

    nonisolated private static func loadTOTPSecret() -> String? {
        if let str = UserDefaults.standard.string(forKey: totpStoreKey), !str.isEmpty {
            return str
        }
        if let url = totpFileURL, let str = try? String(contentsOf: url, encoding: .utf8), !str.isEmpty {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    nonisolated private static func saveTOTPSecret(_ secret: String) {
        UserDefaults.standard.set(secret, forKey: totpStoreKey)
        if let url = totpFileURL {
            try? secret.data(using: .utf8)?.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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
