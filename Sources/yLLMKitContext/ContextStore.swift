import Foundation

public protocol ContextStore: Sendable {
    func createSource(_ source: ContextSource) async throws
    func source(id: ContextSource.ID) async throws -> ContextSource?
    func appendTurn(_ turn: ConversationTurn) async throws
    func turns(for sourceID: ContextSource.ID) async throws -> [ConversationTurn]
    func saveSpan(_ span: ContextSourceSpan) async throws
    func saveChunk(_ chunk: ContextChunk) async throws
    func chunk(id: ContextChunk.ID) async throws -> ContextChunk?
    func markChunkStale(id: ContextChunk.ID) async throws
    func saveSnapshot(_ snapshot: ConversationSnapshot) async throws
    func latestSnapshot(for sourceID: ContextSource.ID) async throws -> ConversationSnapshot?
    func saveMemoryItem(_ item: MemoryItem) async throws
    func search(_ query: ContextSearchQuery) async throws -> [ContextSearchResult]
}

public struct ContextSearchQuery: Codable, Hashable, Sendable {
    public var text: String
    public var sourceID: ContextSource.ID?
    public var limit: Int

    public init(
        text: String,
        sourceID: ContextSource.ID? = nil,
        limit: Int = 20
    ) {
        self.text = text
        self.sourceID = sourceID
        self.limit = limit
    }
}

public struct ContextSearchResult: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var sourceID: ContextSource.ID
    public var recordID: UUID
    public var recordType: ContextSearchRecordType
    public var title: String?
    public var text: String

    public init(
        id: UUID = UUID(),
        sourceID: ContextSource.ID,
        recordID: UUID,
        recordType: ContextSearchRecordType,
        title: String? = nil,
        text: String
    ) {
        self.id = id
        self.sourceID = sourceID
        self.recordID = recordID
        self.recordType = recordType
        self.title = title
        self.text = text
    }
}

public enum ContextSearchRecordType: String, Codable, Hashable, Sendable {
    case source
    case turn
    case span
    case chunk
    case snapshot
    case memoryItem
}
