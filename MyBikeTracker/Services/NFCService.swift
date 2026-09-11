import Combine
import CoreNFC
import Foundation

enum NFCServiceError: LocalizedError, Equatable {
    case notAvailable
    case cancelled
    case unsupportedTag
    case connectFailed
    case writeFailed
    case emptyName

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return NSLocalizedString("nfc_not_available", comment: "")
        case .cancelled:
            return NSLocalizedString("nfc_cancelled", comment: "")
        case .unsupportedTag:
            return NSLocalizedString("nfc_unsupported_tag", comment: "")
        case .connectFailed:
            return NSLocalizedString("nfc_connect_failed", comment: "")
        case .writeFailed:
            return NSLocalizedString("nfc_write_failed", comment: "")
        case .emptyName:
            return NSLocalizedString("nfc_empty_name", comment: "")
        }
    }
}

struct NFCProvisionResult {
    let record: NFCTagRecord
    let wroteNDEF: Bool
}

struct DetectedNFCTag {
    let uid: String?
    let existingAppTagID: UUID?
    let isWritable: Bool
}

@MainActor
final class NFCService: ObservableObject {
    @Published private(set) var tags: [NFCTagRecord]
    @Published private(set) var latestActivation: NFCActivation?

    var isAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    private let store: NFCTagStore
    private let sessionRunner = NFCTagSessionRunner()
    private var lastHandledAt: Date?
    private let debounceInterval: TimeInterval = 2

    init(store: NFCTagStore = NFCTagStore()) {
        self.store = store
        self.tags = store.load()
    }

    func suggestedName() -> String {
        String(
            format: NSLocalizedString("nfc_default_name", comment: ""),
            locale: .current,
            tags.count + 1
        )
    }

    func provisionTag(name: String, action: NFCTagAction) async throws -> NFCProvisionResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NFCServiceError.emptyName }

        let existing = tags
        let result = try await sessionRunner.provision { detected in
            Self.resolve(detected, name: trimmed, action: action, existing: existing)
        }
        upsert(result.record)
        return result
    }

    func updateTag(_ tag: NFCTagRecord) {
        upsert(tag)
    }

    func deleteTag(id: UUID) {
        tags.removeAll { $0.id == id }
        store.save(tags)
    }

    func deleteTags(at offsets: IndexSet) {
        tags.remove(atOffsets: offsets)
        store.save(tags)
    }

    func handleOpenURL(_ url: URL) {
        guard let id = NFCTagRecord.id(from: url),
              let tag = tags.first(where: { $0.id == id }) else { return }
        activate(tag)
    }

    func activate(_ tag: NFCTagRecord) {
        let now = Date()
        if let lastHandledAt, now.timeIntervalSince(lastHandledAt) < debounceInterval {
            return
        }
        lastHandledAt = now
        latestActivation = NFCActivation(tag: tag)
    }

    #if DEBUG
    func simulateTap(action: NFCTagAction = .toggleRide) {
        let tag = tags.first(where: { $0.action == action })
            ?? tags.first
            ?? NFCTagRecord(
                id: UUID(),
                name: "Debug",
                action: action,
                createdAt: Date()
            )
        lastHandledAt = nil
        activate(tag)
    }
    #endif

    private func upsert(_ record: NFCTagRecord) {
        if let index = tags.firstIndex(where: { $0.id == record.id }) {
            tags[index] = record
        } else if let uid = record.tagUID, let index = tags.firstIndex(where: { $0.tagUID == uid }) {
            tags[index] = record
        } else {
            tags.append(record)
        }
        store.save(tags)
    }

    private static func resolve(
        _ detected: DetectedNFCTag,
        name: String,
        action: NFCTagAction,
        existing: [NFCTagRecord]
    ) -> NFCTagRecord {
        if let uid = detected.uid, let match = existing.first(where: { $0.tagUID == uid }) {
            return NFCTagRecord(
                id: match.id,
                name: name,
                action: action,
                createdAt: match.createdAt,
                tagUID: uid
            )
        }

        if let id = detected.existingAppTagID, let match = existing.first(where: { $0.id == id }) {
            return NFCTagRecord(
                id: match.id,
                name: name,
                action: action,
                createdAt: match.createdAt,
                tagUID: detected.uid
            )
        }

        return NFCTagRecord(
            id: detected.existingAppTagID ?? UUID(),
            name: name,
            action: action,
            createdAt: Date(),
            tagUID: detected.uid
        )
    }
}

// MARK: - Core NFC session

private final class NFCTagSessionRunner: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<NFCProvisionResult, Error>?
    private var resolver: ((DetectedNFCTag) -> NFCTagRecord)?
    private var didResume = false

    func provision(
        resolve: @escaping (DetectedNFCTag) -> NFCTagRecord
    ) async throws -> NFCProvisionResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.beginSession(resolve: resolve, continuation: continuation)
            }
        }
    }

    private func beginSession(
        resolve: @escaping (DetectedNFCTag) -> NFCTagRecord,
        continuation: CheckedContinuation<NFCProvisionResult, Error>
    ) {
        if !NFCTagReaderSession.readingAvailable {
            continuation.resume(throwing: NFCServiceError.notAvailable)
            return
        }

        session?.invalidate()
        didResume = false
        self.continuation = continuation
        self.resolver = resolve

        guard let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil) else {
            continuation.resume(throwing: NFCServiceError.notAvailable)
            return
        }
        session.alertMessage = NSLocalizedString("nfc_hold_near_tag", comment: "")
        self.session = session
        session.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        guard !didResume else { return }

        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                resume(.failure(NFCServiceError.cancelled))
                return
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                return
            default:
                break
            }
        }
        resume(.failure(error))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        if tags.count > 1 {
            session.alertMessage = NSLocalizedString("nfc_multiple_tags", comment: "")
            session.restartPolling()
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.fail(session, .connectFailed)
                return
            }
            self.handleConnectedTag(tag, session: session)
        }
    }

    private func handleConnectedTag(_ tag: NFCTag, session: NFCTagReaderSession) {
        let uid = Self.uidHex(from: tag)
        guard let ndefTag = Self.ndefTag(from: tag) else {
            finish(
                session,
                record: resolvedTag(uid: uid, existingID: nil, isWritable: false),
                wroteNDEF: false
            )
            return
        }

        ndefTag.queryNDEFStatus { [weak self] status, _, error in
            guard let self else { return }
            if error != nil {
                self.fail(session, .unsupportedTag)
                return
            }

            switch status {
            case .readWrite:
                self.readThenWrite(ndefTag, session: session, uid: uid)
            case .readOnly:
                ndefTag.readNDEF { [weak self] message, _ in
                    guard let self else { return }
                    let existingID = message?.appTagID
                    self.finish(
                        session,
                        record: self.resolvedTag(uid: uid, existingID: existingID, isWritable: false),
                        wroteNDEF: false
                    )
                }
            case .notSupported:
                self.finish(
                    session,
                    record: self.resolvedTag(uid: uid, existingID: nil, isWritable: false),
                    wroteNDEF: false
                )
            @unknown default:
                self.fail(session, .unsupportedTag)
            }
        }
    }

    private func readThenWrite(_ ndefTag: NFCNDEFTag, session: NFCTagReaderSession, uid: String?) {
        ndefTag.readNDEF { [weak self] message, _ in
            guard let self else { return }
            let record = self.resolvedTag(uid: uid, existingID: message?.appTagID, isWritable: true)
            guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: NFCTagRecord.url(for: record.id)) else {
                self.fail(session, .writeFailed)
                return
            }

            let ndefMessage = NFCNDEFMessage(records: [payload])
            ndefTag.writeNDEF(ndefMessage) { [weak self] error in
                guard let self else { return }
                if error != nil {
                    self.fail(session, .writeFailed)
                    return
                }
                self.finish(session, record: record, wroteNDEF: true)
            }
        }
    }

    private func resolvedTag(uid: String?, existingID: UUID?, isWritable: Bool) -> NFCTagRecord {
        let detected = DetectedNFCTag(uid: uid, existingAppTagID: existingID, isWritable: isWritable)
        if let resolver {
            return resolver(detected)
        }
        return NFCTagRecord(id: existingID ?? UUID(), name: "", action: .toggleRide, createdAt: Date(), tagUID: uid)
    }

    private func finish(_ session: NFCTagReaderSession, record: NFCTagRecord, wroteNDEF: Bool) {
        session.alertMessage = NSLocalizedString(
            wroteNDEF ? "nfc_write_success" : "nfc_readonly_saved",
            comment: ""
        )
        resume(.success(NFCProvisionResult(record: record, wroteNDEF: wroteNDEF)))
        session.invalidate()
    }

    private func fail(_ session: NFCTagReaderSession, _ error: NFCServiceError) {
        resume(.failure(error))
        session.invalidate(errorMessage: error.localizedDescription)
    }

    private func resume(_ result: Result<NFCProvisionResult, Error>) {
        guard !didResume else { return }
        didResume = true
        let continuation = self.continuation
        self.continuation = nil
        resolver = nil
        continuation?.resume(with: result)
    }

    private static func ndefTag(from tag: NFCTag) -> NFCNDEFTag? {
        switch tag {
        case .miFare(let tag): return tag
        case .iso15693(let tag): return tag
        case .iso7816(let tag): return tag
        case .feliCa(let tag): return tag
        @unknown default: return nil
        }
    }

    private static func uidHex(from tag: NFCTag) -> String? {
        let data: Data?
        switch tag {
        case .miFare(let tag): data = tag.identifier
        case .iso15693(let tag): data = tag.identifier
        case .iso7816(let tag): data = tag.identifier
        case .feliCa(let tag): data = tag.currentIDm
        @unknown default: data = nil
        }
        guard let data, !data.isEmpty else { return nil }
        return data.map { String(format: "%02X", $0) }.joined()
    }
}

private extension NFCNDEFMessage {
    var appTagID: UUID? {
        for record in records {
            if let url = record.wellKnownTypeURIPayload(), let id = NFCTagRecord.id(from: url) {
                return id
            }
        }
        return nil
    }
}
