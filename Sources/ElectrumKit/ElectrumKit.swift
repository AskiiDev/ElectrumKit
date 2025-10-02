import Foundation
import CryptoKit
import Security
import Network

/// Errors thrown by the Electrum client
public enum ElectrumError: Error {
    case certificateError(String)
    case certificateMismatch
    case connectionFailed(Error)
    case unknown
}

/// Lightweight Electrum client
public final class ElectrumClient {
    private let host: String
    private let port: UInt16
    
    private var requests: [Int: Any]
    private var subscriptions: [String: Any]
    
    private let pinnedService = "electrum.client.certificates.pinned"
    private let caTrustService = "electrum.client.certificates.ca"
    
    private let pinnedKeychainQuery: [String: Any]
    private let caKeychainQuery: [String: Any]
    
    private var connection: NWConnection?
    
    private let mainQueue: DispatchQueue
    private let tlsQueue: DispatchQueue
    
    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        
        requests = [:]
        subscriptions = [:]
        
        mainQueue = DispatchQueue(
            label: "\(host).main",
            attributes: .concurrent
        )
        tlsQueue = DispatchQueue(
            label: "\(host).tls"
        )
        
        caKeychainQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: caTrustService,
            kSecAttrAccount as String: host
        ]
        pinnedKeychainQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: pinnedService,
            kSecAttrAccount as String: host,
        ]
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public API
    
    /// Starts the client and initiates a connection to the server
    public func start() {
        mainQueue.async(flags: .barrier) { [weak self] in
            self?.connect()
        }
    }
    
    /// Stops the client and gracefully terminates the connection
    public func stop() {
        mainQueue.async(flags: .barrier) { [weak self] in
            self?.disconnect()
        }
    }
    
    // MARK: - Connection Management
    
    /// Sets up and starts the NWConnection
    private func connect() {
        let options = NWProtocolTLS.Options()
        let secOptions = options.securityProtocolOptions
       
        // TLS < 1.2 is fully deprecated
        sec_protocol_options_set_min_tls_protocol_version(
            secOptions,
            .TLSv12
        )
        
        sec_protocol_options_set_verify_block(
            secOptions,
            { [weak self] metadata, trust, callback in
                // Can't verify if the
                // client doesn't exist
                guard let self = self else {
                    callback(false)
                    return
                }
                
                // Custom verification for
                // CA & self-signed certs
                self.verifyTLS(
                    metadata: metadata,
                    trust: trust,
                    callback: callback
                )
            },
            tlsQueue
        )
        
        let parameters = NWParameters(tls: options)
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )

        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleStateUpdate(state)
        }
        connection?.start(queue: mainQueue)
    }
    
    /// Cancels the connection and resets state
    private func disconnect() {
        connection?.cancel()
        connection = nil
        
        requests.removeAll()
        subscriptions.removeAll()
    }
    
    // TODO: Handles updates to the connection state.
    private func handleStateUpdate(_ state: NWConnection.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            break
        case .waiting(let error):
            break
        case .cancelled:
            break
        default:
            break
        }
    }
    
    // MARK: - TLS Verification
        
    /// Verifies TLS certificate using the TOFU strategy
    private func verifyTLS(
        metadata: sec_protocol_metadata_t,
        trust: sec_trust_t,
        callback: @escaping (Bool) -> Void
    ) {
        let ref = sec_trust_copy_ref(trust).takeRetainedValue()
        let trusted = SecTrustEvaluateWithError(ref, nil)
        
        // Subsequent connection, we check if
        // host has been marked as CA trusted
        if loadCaTrustMarker() {
            callback(trusted)
            return
        }
        
        guard
            let chain = SecTrustCopyCertificateChain(ref) as? [SecCertificate],
            let certificate = chain.first
        else {
            callback(false)
            return
        }
        
        // Subsequent connection, we check if
        // host has been marked as self signed
        if let pinned = loadPinnedCertificate() {
            SecTrustSetAnchorCertificates(ref, [pinned] as CFArray)
            SecTrustSetAnchorCertificatesOnly(ref, true)
            
            // We explicitly do not want to check
            // hostnames for self signed certs
            let policy = SecPolicyCreateSSL(true, nil)
            SecTrustSetPolicies(ref, [policy] as CFArray)
            
            let serverData = SecCertificateCopyData(certificate) as Data
            let pinnedData = SecCertificateCopyData(pinned) as Data
            
            if serverData != pinnedData {
                callback(false)
                return
            }
            
            if SecTrustEvaluateWithError(ref, nil) {
                callback(true)
            } else {
                deleteCertificateAndTrustMarker()
                callback(false)
            }
            
            return
        }
        
        // First Use (TOFU): No certificate or CA trust marker found
        if trusted {
            callback(saveCaTrustMarker())
        } else {
            callback(savePinnedCertificate(certificate))
        }
    }
    
    // MARK: - Certificate Keychain Storage
    
    private func savePinnedCertificate(_ certificate: SecCertificate) -> Bool {
        deleteCertificateAndTrustMarker()

        let data = SecCertificateCopyData(certificate) as Data
        var query = pinnedKeychainQuery
        
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func loadPinnedCertificate() -> SecCertificate? {
        var query = pinnedKeychainQuery

        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let certificate = SecCertificateCreateWithData(nil, data as CFData)
        else {
            return nil
        }
        
        return certificate
    }

    private func saveCaTrustMarker() -> Bool {
        deleteCertificateAndTrustMarker()
        
        var query = caKeychainQuery
        
        query[kSecValueData as String] = Data()
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func loadCaTrustMarker() -> Bool {
        var query = caKeychainQuery
        
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    private func deleteCertificateAndTrustMarker() {
        SecItemDelete(pinnedKeychainQuery as CFDictionary)
        SecItemDelete(caKeychainQuery as CFDictionary)
    }
}
