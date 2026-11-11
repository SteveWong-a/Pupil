//
//  WebPushManager.swift
//  Pupil
//
//  Native macOS W3C Web Push (RFC 8030 / RFC 8291 aes128gcm / RFC 8292 VAPID) engine
//  and one-time QR code companion pairing manager using Apple CryptoKit and CoreImage.
//

import AppKit
import CoreImage
import CryptoKit
import Foundation
import Observation

public struct WebPushSubscription: Codable, Sendable, Equatable {
    public let endpoint: String
    public let p256dh: String
    public let auth: String
    public let deviceName: String
    public let pairedAt: Date

    public init(
        endpoint: String,
        p256dh: String,
        auth: String,
        deviceName: String = "iPhone",
        pairedAt: Date = Date()
    ) {
        self.endpoint = endpoint
        self.p256dh = p256dh
        self.auth = auth
        self.deviceName = deviceName
        self.pairedAt = pairedAt
    }

    public var endpointHost: String {
        guard let url = URL(string: endpoint), let host = url.host else {
            return "Apple Web Push"
        }
        return host
    }
}

public enum WebPushError: Error, LocalizedError, Sendable {
    case invalidEndpointURL
    case invalidReceiverPublicKey
    case invalidAuthSecret
    case encryptionFailed
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpointURL:
            return "Invalid Web Push endpoint URL."
        case .invalidReceiverPublicKey:
            return "Invalid P-256 receiver public key (p256dh)."
        case .invalidAuthSecret:
            return "Invalid Web Push authentication secret."
        case .encryptionFailed:
            return "Failed to encrypt RFC 8291 aes128gcm payload."
        case let .httpError(code, msg):
            return "Push server returned HTTP \(code): \(msg)"
        }
    }
}

extension Data {
    public func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public init?(base64URLEncoded input: String) {
        var base64 = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }
}

@MainActor
@Observable
public final class WebPushManager {
    public static let companionBaseURL = "https://stevewong-a.github.io/pupil/"

    public private(set) var isListeningForPairing: Bool = false
    public private(set) var isSendingPush: Bool = false
    public private(set) var statusMessage: String?
    public private(set) var lastPushDate: Date?
    public private(set) var lastPushSucceeded: Bool = true

    private let settings: PupilSettings
    private var pairingPollTimer: Timer?

    public init(settings: PupilSettings = .shared) {
        self.settings = settings
        ensureVAPIDIdentity()
    }

    // MARK: - VAPID Identity & Companion QR URL

    public var vapidPrivateKey: P256.Signing.PrivateKey {
        ensureVAPIDIdentity()
        if let keyData = Data(base64URLEncoded: settings.vapidPrivateKeyRaw),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
            return key
        }
        let fresh = P256.Signing.PrivateKey()
        settings.vapidPrivateKeyRaw = fresh.rawRepresentation.base64URLEncodedString()
        return fresh
    }

    /// 65-byte ANSI X9.63 uncompressed P-256 public key (`0x04 || X || Y`) in Base64URL format.
    public var vapidPublicKeyBase64URL: String {
        vapidPrivateKey.publicKey.x963Representation.base64URLEncodedString()
    }

    public var pairingURLString: String {
        ensureVAPIDIdentity()
        var components = URLComponents(string: Self.companionBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "v", value: vapidPublicKeyBase64URL),
            URLQueryItem(name: "c", value: settings.pairingChannelID)
        ]
        return components.url?.absoluteString ?? Self.companionBaseURL
    }

    public var activeSubscription: WebPushSubscription? {
        settings.pairedPhoneSubscription
    }

    public var isPaired: Bool {
        activeSubscription != nil
    }

    private func ensureVAPIDIdentity() {
        if settings.vapidPrivateKeyRaw.isEmpty ||
            Data(base64URLEncoded: settings.vapidPrivateKeyRaw) == nil {
            let key = P256.Signing.PrivateKey()
            settings.vapidPrivateKeyRaw = key.rawRepresentation.base64URLEncodedString()
        }
        if settings.pairingChannelID.isEmpty {
            settings.pairingChannelID = Self.generateRandomChannelID()
        }
    }

    public func regeneratePairingChannel() {
        settings.pairingChannelID = Self.generateRandomChannelID()
        statusMessage = "Generated fresh QR pairing code."
    }

    public static func generateRandomChannelID() -> String {
        var bytes = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "pupil-pair-\(hex)"
    }

    // MARK: - Native CoreImage QR Code Generator

    public func makePairingQRCodeImage(dimension: CGFloat = 164) -> NSImage? {
        guard let data = pairingURLString.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let extent = outputImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let scale = max(1.0, floor(dimension / extent.width))
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: dimension, height: dimension))
    }

    // MARK: - One-Time Automatic Pairing & Clipboard Import

    public func startPairingListener() {
        stopPairingListener()
        guard !isPaired else { return }
        isListeningForPairing = true

        // Check immediately, then poll every 2.5s while the QR code is visible
        Task { [weak self] in
            await self?.pollPairingRendezvousOnce()
        }

        pairingPollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaired else {
                    self?.stopPairingListener()
                    return
                }
                await self.pollPairingRendezvousOnce()
            }
        }
    }

    public func stopPairingListener() {
        pairingPollTimer?.invalidate()
        pairingPollTimer = nil
        isListeningForPairing = false
    }

    private func pollPairingRendezvousOnce() async {
        let channel = settings.pairingChannelID
        guard !channel.isEmpty,
              let url = URL(string: "https://ntfy.sh/\(channel)/json?poll=1&since=15m") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }

            let lines = text.split(whereSeparator: \.isNewline).reversed()
            for line in lines {
                guard let lineData = String(line).data(using: .utf8),
                      let envelope = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let message = envelope["message"] as? String,
                      message.hasPrefix("pupilpair://") else {
                    continue
                }
                if importPairingToken(message) {
                    stopPairingListener()
                    Task { [weak self] in
                        _ = await self?.sendPushNotification(
                            title: "✅ Pupil Paired with Your Mac",
                            body: "Lock-screen security alerts are now active for your MacBook.",
                            severity: "normal",
                            tag: "pupil-paired"
                        )
                    }
                    return
                }
            }
        } catch {
            // Silent retry on next poll tick
        }
    }

    @discardableResult
    public func pastePairingFromClipboard() -> Bool {
        guard let raw = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            statusMessage = "Clipboard is empty. Tap 'Copy Pairing Code' on your phone first."
            return false
        }
        let ok = importPairingToken(raw)
        if ok {
            Task { [weak self] in
                _ = await self?.sendPushNotification(
                    title: "✅ Pupil Paired with Your Mac",
                    body: "Lock-screen security alerts are now active for your MacBook.",
                    severity: "normal",
                    tag: "pupil-paired"
                )
            }
        } else {
            statusMessage = "Clipboard does not contain a valid Pupil pairing token."
        }
        return ok
    }

    @discardableResult
    public func importPairingToken(_ rawInput: String) -> Bool {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonData: Data

        if trimmed.hasPrefix("pupilpair://") {
            let b64Part = String(trimmed.dropFirst("pupilpair://".count))
            guard let decoded = Data(base64URLEncoded: b64Part) else {
                return false
            }
            jsonData = decoded
        } else if let directData = trimmed.data(using: .utf8) {
            jsonData = directData
        } else {
            return false
        }

        guard let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return false
        }

        let endpoint = (obj["endpoint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keysDict = obj["keys"] as? [String: Any]
        let p256dh = (obj["p256dh"] as? String) ?? (keysDict?["p256dh"] as? String) ?? ""
        let auth = (obj["auth"] as? String) ?? (keysDict?["auth"] as? String) ?? ""
        let deviceName = (obj["deviceName"] as? String) ?? "iPhone"

        guard let parsedURL = URL(string: endpoint),
              parsedURL.scheme?.lowercased() == "https",
              let pubKeyBytes = Data(base64URLEncoded: p256dh),
              (try? P256.KeyAgreement.PublicKey(x963Representation: pubKeyBytes)) != nil,
              let authBytes = Data(base64URLEncoded: auth),
              authBytes.count >= 12 else {
            return false
        }

        let sub = WebPushSubscription(
            endpoint: endpoint,
            p256dh: p256dh,
            auth: auth,
            deviceName: deviceName,
            pairedAt: Date()
        )
        settings.pairedPhoneSubscription = sub
        settings.relayEnabled = true
        statusMessage = "Paired with \(deviceName) (\(sub.endpointHost))."
        return true
    }

    public func unpairPhone() {
        settings.pairedPhoneSubscription = nil
        statusMessage = "Phone unpaired."
        regeneratePairingChannel()
    }

    // MARK: - Direct Push Delivery to Apple (web.push.apple.com)

    @discardableResult
    public func sendPushNotification(
        title: String,
        body: String,
        severity: String = "high",
        tag: String = "pupil-security-alert"
    ) async -> Bool {
        guard settings.relayEnabled, let subscription = settings.pairedPhoneSubscription else {
            return false
        }
        guard let endpointURL = URL(string: subscription.endpoint) else {
            statusMessage = "Invalid push endpoint URL."
            lastPushSucceeded = false
            return false
        }

        isSendingPush = true
        defer { isSendingPush = false }

        do {
            let payloadDict: [String: Any] = [
                "title": title,
                "body": body,
                "severity": severity,
                "tag": tag,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            let plaintext = try JSONSerialization.data(withJSONObject: payloadDict)
            let encryptedBody = try Self.encryptWebPushPayload(
                plaintext,
                p256dhBase64URL: subscription.p256dh,
                authBase64URL: subscription.auth
            )
            let vapidHeader = try Self.makeVAPIDAuthorizationHeader(
                for: endpointURL,
                privateKey: vapidPrivateKey
            )

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 8.0
            request.httpBody = encryptedBody
            request.setValue(vapidHeader, forHTTPHeaderField: "Authorization")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("aes128gcm", forHTTPHeaderField: "Content-Encoding")
            request.setValue("\(encryptedBody.count)", forHTTPHeaderField: "Content-Length")
            request.setValue("300", forHTTPHeaderField: "TTL")
            request.setValue(severity == "critical" ? "high" : "high", forHTTPHeaderField: "Urgency")
            request.setValue(tag, forHTTPHeaderField: "Topic")

            let (respData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lastPushSucceeded = false
                statusMessage = "Push failed: non-HTTP response."
                return false
            }

            if (200 ... 299).contains(http.statusCode) {
                lastPushDate = Date()
                lastPushSucceeded = true
                statusMessage = "Alert delivered to \(subscription.deviceName)."
                return true
            } else {
                let errText = String(data: respData, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                lastPushSucceeded = false
                statusMessage = "Push error (\(http.statusCode)): \(errText.prefix(80))"
                return false
            }
        } catch {
            lastPushSucceeded = false
            statusMessage = "Push error: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Pure Swift CryptoKit RFC 8292 (VAPID) & RFC 8291 (aes128gcm)

    /// Creates a signed RFC 8292 VAPID Authorization header (`vapid t=<jwt>, k=<pubkey>`).
    public nonisolated static func makeVAPIDAuthorizationHeader(
        for endpointURL: URL,
        privateKey: P256.Signing.PrivateKey,
        subject: String = "mailto:security@pupil.app",
        expirationSeconds: Int = 43200
    ) throws -> String {
        guard let scheme = endpointURL.scheme, let host = endpointURL.host else {
            throw WebPushError.invalidEndpointURL
        }
        let portPart: String
        if let port = endpointURL.port, port != 80, port != 443 {
            portPart = ":\(port)"
        } else {
            portPart = ""
        }
        let audience = "\(scheme)://\(host)\(portPart)"
        let exp = Int(Date().timeIntervalSince1970) + expirationSeconds

        let headerJSON = #"{"typ":"JWT","alg":"ES256"}"#
        let payloadObj: [String: Any] = [
            "aud": audience,
            "exp": exp,
            "sub": subject
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payloadObj)

        let headerB64 = Data(headerJSON.utf8).base64URLEncodedString()
        let payloadB64 = payloadData.base64URLEncodedString()
        let signingInput = "\(headerB64).\(payloadB64)"

        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        let sigB64 = signature.rawRepresentation.base64URLEncodedString()
        let jwt = "\(signingInput).\(sigB64)"
        let publicKeyB64 = privateKey.publicKey.x963Representation.base64URLEncodedString()

        return "vapid t=\(jwt), k=\(publicKeyB64)"
    }

    /// Encrypts a Web Push payload according to RFC 8291 (Web Push Message Encryption) and RFC 8188 (`aes128gcm`).
    public nonisolated static func encryptWebPushPayload(
        _ plaintext: Data,
        p256dhBase64URL: String,
        authBase64URL: String
    ) throws -> Data {
        guard let uaPublicBytes = Data(base64URLEncoded: p256dhBase64URL),
              let uaPublicKey = try? P256.KeyAgreement.PublicKey(x963Representation: uaPublicBytes) else {
            throw WebPushError.invalidReceiverPublicKey
        }
        guard let authSecret = Data(base64URLEncoded: authBase64URL), authSecret.count >= 12 else {
            throw WebPushError.invalidAuthSecret
        }

        let asPrivateKey = P256.KeyAgreement.PrivateKey()
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }

        return try encryptWebPushPayloadDeterministic(
            plaintext,
            uaPublicKey: uaPublicKey,
            authSecret: authSecret,
            asPrivateKey: asPrivateKey,
            salt: salt
        )
    }

    /// Deterministic core of RFC 8291 + RFC 8188 `aes128gcm` encryption for unit testing & verification.
    public nonisolated static func encryptWebPushPayloadDeterministic(
        _ plaintext: Data,
        uaPublicKey: P256.KeyAgreement.PublicKey,
        authSecret: Data,
        asPrivateKey: P256.KeyAgreement.PrivateKey,
        salt: Data
    ) throws -> Data {
        let uaPublicBytes = uaPublicKey.x963Representation
        let asPublicBytes = asPrivateKey.publicKey.x963Representation
        let sharedSecret = try asPrivateKey.sharedSecretFromKeyAgreement(with: uaPublicKey)

        // RFC 8291 Section 3.3: key_info = "WebPush: info\0" || ua_public || as_public
        var keyInfo = Data("WebPush: info\0".utf8)
        keyInfo.append(uaPublicBytes)
        keyInfo.append(asPublicBytes)

        let ikmKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: authSecret,
            sharedInfo: keyInfo,
            outputByteCount: 32
        )

        // RFC 8188 Section 2.2 & 2.3: Derive 16-byte CEK and 12-byte NONCE from IKM and 16-byte salt
        let cekInfo = Data("Content-Encoding: aes128gcm\0".utf8)
        let nonceInfo = Data("Content-Encoding: nonce\0".utf8)

        let cek = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikmKey,
            salt: salt,
            info: cekInfo,
            outputByteCount: 16
        )
        let nonceKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikmKey,
            salt: salt,
            info: nonceInfo,
            outputByteCount: 12
        )
        let nonceBytes = nonceKey.withUnsafeBytes { Data($0) }
        let nonce = try AES.GCM.Nonce(data: nonceBytes)

        // RFC 8188 Section 2: Final record delimiter 0x02 appended to plaintext
        var paddedPlaintext = plaintext
        paddedPlaintext.append(0x02)

        let sealed = try AES.GCM.seal(paddedPlaintext, using: cek, nonce: nonce)

        // RFC 8188 Section 2.1 Header: salt (16B) || rs (4B big-endian, 4096) || idlen (1B, 65) || keyid (65B as_public)
        var body = Data()
        body.reserveCapacity(86 + paddedPlaintext.count + 16)
        body.append(salt)
        var rsBigEndian = UInt32(4096).bigEndian
        withUnsafeBytes(of: &rsBigEndian) { body.append(contentsOf: $0) }
        body.append(UInt8(asPublicBytes.count))
        body.append(asPublicBytes)
        body.append(sealed.ciphertext)
        body.append(sealed.tag)

        return body
    }

    /// Decrypts an RFC 8291 `aes128gcm` Web Push payload (used in unit tests to verify round-trip cryptographic compliance).
    public nonisolated static func decryptWebPushPayload(
        _ encryptedBody: Data,
        receiverPrivateKey: P256.KeyAgreement.PrivateKey,
        authSecret: Data
    ) throws -> Data {
        guard encryptedBody.count > 86 + 16 else {
            throw WebPushError.encryptionFailed
        }
        let salt = encryptedBody.subdata(in: 0 ..< 16)
        let idLen = Int(encryptedBody[20])
        guard idLen == 65, encryptedBody.count > 21 + idLen + 16 else {
            throw WebPushError.encryptionFailed
        }
        let asPublicBytes = encryptedBody.subdata(in: 21 ..< (21 + idLen))
        let ciphertextAndTag = encryptedBody.subdata(in: (21 + idLen) ..< encryptedBody.count)

        let asPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: asPublicBytes)
        let uaPublicBytes = receiverPrivateKey.publicKey.x963Representation
        let sharedSecret = try receiverPrivateKey.sharedSecretFromKeyAgreement(with: asPublicKey)

        var keyInfo = Data("WebPush: info\0".utf8)
        keyInfo.append(uaPublicBytes)
        keyInfo.append(asPublicBytes)

        let ikmKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: authSecret,
            sharedInfo: keyInfo,
            outputByteCount: 32
        )

        let cek = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikmKey,
            salt: salt,
            info: Data("Content-Encoding: aes128gcm\0".utf8),
            outputByteCount: 16
        )
        let nonceKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikmKey,
            salt: salt,
            info: Data("Content-Encoding: nonce\0".utf8),
            outputByteCount: 12
        )
        let nonceBytes = nonceKey.withUnsafeBytes { Data($0) }
        let nonce = try AES.GCM.Nonce(data: nonceBytes)

        let ciphertext = ciphertextAndTag.dropLast(16)
        let tag = ciphertextAndTag.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        var decrypted = try AES.GCM.open(sealedBox, using: cek)

        // Strip trailing padding zeros and 0x02 delimiter
        while let last = decrypted.last, last == 0x00 {
            decrypted.removeLast()
        }
        guard decrypted.last == 0x02 else {
            throw WebPushError.encryptionFailed
        }
        decrypted.removeLast()
        return decrypted
    }
}
