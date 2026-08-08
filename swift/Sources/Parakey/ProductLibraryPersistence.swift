import Foundation
import SuperDictateCore

struct ProductLegacyHistoryValue: Sendable {
    let text: String
    let transcriptionDurationSeconds: Double?
}

/// The background agent is the only durable Library writer.
///
/// Calls are fire-and-forget from the runtime main actor. Commands carry a
/// monotonic revision so an older detached task can never undo a newer privacy
/// decision such as History = Off.
enum ProductLibraryPersistence {
    @MainActor private static var commandRevision: UInt64 = 0

    @MainActor
    static func scheduleLegacyHistoryMerge(_ values: [ProductLegacyHistoryValue]) {
        guard !values.isEmpty else { return }
        guard let rootDirectory = resolvedRootDirectory() else { return }

        let entries = values.map {
            SuperDictateLegacyHistoryEntry(
                text: $0.text,
                transcriptionDurationSeconds: $0.transcriptionDurationSeconds
            )
        }
        let revision = nextRevision()

        Task.detached(priority: .utility) {
            await ProductLibraryPersistenceWorker.shared.submit(
                .merge(entries),
                revision: revision,
                rootDirectory: rootDirectory
            )
        }
    }

    @MainActor
    static func scheduleClear() {
        guard let rootDirectory = resolvedRootDirectory() else { return }
        let revision = nextRevision()
        Task.detached(priority: .utility) {
            await ProductLibraryPersistenceWorker.shared.submit(
                .clear,
                revision: revision,
                rootDirectory: rootDirectory
            )
        }
    }

    @MainActor
    private static func nextRevision() -> UInt64 {
        commandRevision &+= 1
        return commandRevision
    }

    @MainActor
    private static func resolvedRootDirectory() -> URL? {
        do {
            return try superDictateApplicationSupportDirectory()
        } catch {
            log("product Library root unavailable: \(error.localizedDescription)")
            return nil
        }
    }
}

private actor ProductLibraryPersistenceWorker {
    enum Operation: Sendable {
        case merge([SuperDictateLegacyHistoryEntry])
        case clear
    }

    private struct PendingOperation: Sendable {
        let operation: Operation
        let revision: UInt64
        let rootDirectory: URL
    }

    static let shared = ProductLibraryPersistenceWorker()

    private var store: JSONSuperDictateLibraryStore?
    private var storeRootDirectory: URL?
    private var latestRevision: UInt64 = 0
    private var pendingOperation: PendingOperation?
    private var isProcessing = false

    func submit(
        _ operation: Operation,
        revision: UInt64,
        rootDirectory: URL
    ) async {
        guard revision > latestRevision else { return }
        latestRevision = revision
        pendingOperation = PendingOperation(
            operation: operation,
            revision: revision,
            rootDirectory: rootDirectory
        )

        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let pending = pendingOperation {
            pendingOperation = nil
            await process(pending)
        }
    }

    private func process(_ pending: PendingOperation) async {
        do {
            let store = try libraryStore(rootDirectory: pending.rootDirectory)

            switch pending.operation {
            case .merge(let entries):
                guard !entries.isEmpty else { return }
                let archive = try await store.load()
                guard pending.revision == latestRevision else { return }

                let result = SuperDictateLegacyLibraryMerger.merge(entries, into: archive)
                guard result.changed else { return }
                guard pending.revision == latestRevision else { return }

                try await store.save(result.archive)
                log(
                    "product Library merged legacy history "
                    + "(recordings=\(result.addedRecordingCount), documents=\(result.addedDocumentCount))"
                )

            case .clear:
                guard pending.revision == latestRevision else { return }
                try await store.save(SuperDictateLibraryArchive())
                log("product Library cleared because transcript history is disabled")
            }
        } catch {
            log("product Library persistence failed: \(error.localizedDescription)")
        }
    }

    private func libraryStore(
        rootDirectory: URL
    ) throws -> JSONSuperDictateLibraryStore {
        if let store,
           storeRootDirectory == rootDirectory {
            return store
        }

        let created = try JSONSuperDictateLibraryStore(rootDirectory: rootDirectory)
        store = created
        storeRootDirectory = rootDirectory
        return created
    }
}
