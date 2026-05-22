import Foundation
import GRDB
import yLLMKit

public final class GRDBContextStore: ContextStore, @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) throws {
        self.dbQueue = try DatabaseQueue(path: path)
        try migrate()
    }

    public init(inMemoryIdentifier: String = UUID().uuidString) throws {
        self.dbQueue = try DatabaseQueue(path: "file:\(inMemoryIdentifier)?mode=memory&cache=shared")
        try migrate()
    }

    public func createSource(_ source: ContextSource) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO context_sources
                (id, kind, title, content_hash, created_at, updated_at, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    source.id.uuidString,
                    source.kind.rawValue,
                    source.title,
                    source.contentHash,
                    source.createdAt.timeIntervalSince1970,
                    source.updatedAt.timeIntervalSince1970,
                    try jsonString(source.metadata)
                ]
            )
            try upsertSearch(
                db,
                sourceID: source.id,
                recordID: source.id,
                recordType: .source,
                title: source.title,
                body: [source.title, source.metadata.values.joined(separator: " ")]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            )
        }
    }

    public func source(id: ContextSource.ID) async throws -> ContextSource? {
        try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM context_sources WHERE id = ?",
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try decodeSource(row)
        }
    }

    public func appendTurn(_ turn: ConversationTurn) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO conversation_turns
                (id, source_id, turn_index, role, content, token_estimate, created_at, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    turn.id.uuidString,
                    turn.sourceID.uuidString,
                    turn.turnIndex,
                    turn.role.rawValue,
                    turn.content,
                    turn.tokenEstimate,
                    turn.createdAt.timeIntervalSince1970,
                    try jsonString(turn.metadata)
                ]
            )
            try upsertSearch(
                db,
                sourceID: turn.sourceID,
                recordID: turn.id,
                recordType: .turn,
                title: "Turn \(turn.turnIndex)",
                body: turn.content
            )
        }
    }

    public func turns(for sourceID: ContextSource.ID) async throws -> [ConversationTurn] {
        try await dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM conversation_turns WHERE source_id = ? ORDER BY turn_index",
                arguments: [sourceID.uuidString]
            ).map(decodeTurn)
        }
    }

    public func saveSpan(_ span: ContextSourceSpan) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO source_spans
                (id, source_id, start_offset, end_offset, section_title, text, token_estimate, content_hash)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    span.id.uuidString,
                    span.sourceID.uuidString,
                    span.startOffset,
                    span.endOffset,
                    span.sectionTitle,
                    span.text,
                    span.tokenEstimate,
                    span.contentHash
                ]
            )
            try upsertSearch(
                db,
                sourceID: span.sourceID,
                recordID: span.id,
                recordType: .span,
                title: span.sectionTitle,
                body: span.text ?? ""
            )
        }
    }

    public func saveChunk(_ chunk: ContextChunk) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO context_chunks
                (id, source_id, level, kind, text, token_estimate, source_references_json, content_hash, is_stale, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    chunk.id.uuidString,
                    chunk.sourceID.uuidString,
                    chunk.level,
                    chunk.kind.rawValue,
                    chunk.text,
                    chunk.tokenEstimate,
                    try jsonString(chunk.sourceReferences),
                    chunk.contentHash,
                    chunk.isStale ? 1 : 0,
                    chunk.createdAt.timeIntervalSince1970,
                    chunk.updatedAt.timeIntervalSince1970
                ]
            )
            try upsertSearch(
                db,
                sourceID: chunk.sourceID,
                recordID: chunk.id,
                recordType: .chunk,
                title: "Chunk \(chunk.level)",
                body: chunk.text
            )
        }
    }

    public func chunk(id: ContextChunk.ID) async throws -> ContextChunk? {
        try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM context_chunks WHERE id = ?",
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try decodeChunk(row)
        }
    }

    public func markChunkStale(id: ContextChunk.ID) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE context_chunks SET is_stale = 1, updated_at = ? WHERE id = ?",
                arguments: [Date().timeIntervalSince1970, id.uuidString]
            )
        }
    }

    public func saveSnapshot(_ snapshot: ConversationSnapshot) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO context_snapshots
                (id, source_id, summary, token_estimate, built_through_reference_json, source_references_json, content_hash, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    snapshot.id.uuidString,
                    snapshot.sourceID.uuidString,
                    snapshot.summary,
                    snapshot.tokenEstimate,
                    try jsonString(snapshot.builtThroughReference),
                    try jsonString(snapshot.sourceReferences),
                    snapshot.contentHash,
                    snapshot.createdAt.timeIntervalSince1970
                ]
            )
            try upsertSearch(
                db,
                sourceID: snapshot.sourceID,
                recordID: snapshot.id,
                recordType: .snapshot,
                title: "Snapshot",
                body: snapshot.summary
            )
        }
    }

    public func latestSnapshot(for sourceID: ContextSource.ID) async throws -> ConversationSnapshot? {
        try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM context_snapshots WHERE source_id = ? ORDER BY created_at DESC LIMIT 1",
                arguments: [sourceID.uuidString]
            ) else {
                return nil
            }
            return try decodeSnapshot(row)
        }
    }

    public func saveMemoryItem(_ item: MemoryItem) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO memory_items
                (id, source_id, kind, text, source_references_json, confidence, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    item.id.uuidString,
                    item.sourceID.uuidString,
                    item.kind.rawValue,
                    item.text,
                    try jsonString(item.sourceReferences),
                    item.confidence.rawValue,
                    item.status.rawValue,
                    item.createdAt.timeIntervalSince1970,
                    item.updatedAt.timeIntervalSince1970
                ]
            )
            try upsertSearch(
                db,
                sourceID: item.sourceID,
                recordID: item.id,
                recordType: .memoryItem,
                title: item.kind.rawValue,
                body: item.text
            )
        }
    }

    public func search(_ query: ContextSearchQuery) async throws -> [ContextSearchResult] {
        let trimmed = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return try await dbQueue.read { db in
            let rows: [Row]
            if let sourceID = query.sourceID {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT source_id, record_id, record_type, title, body
                    FROM context_search
                    WHERE context_search MATCH ? AND source_id = ?
                    LIMIT ?
                    """,
                    arguments: [trimmed, sourceID.uuidString, query.limit]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT source_id, record_id, record_type, title, body
                    FROM context_search
                    WHERE context_search MATCH ?
                    LIMIT ?
                    """,
                    arguments: [trimmed, query.limit]
                )
            }
            return try rows.map(decodeSearchResult)
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createContextStoreV1") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS context_sources (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                title TEXT,
                content_hash TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                metadata_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS conversation_turns (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                turn_index INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                token_estimate INTEGER,
                created_at REAL NOT NULL,
                metadata_json TEXT NOT NULL,
                FOREIGN KEY (source_id) REFERENCES context_sources(id)
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_turns_source_index
            ON conversation_turns(source_id, turn_index);

            CREATE TABLE IF NOT EXISTS source_spans (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                start_offset INTEGER NOT NULL,
                end_offset INTEGER NOT NULL,
                section_title TEXT,
                text TEXT,
                token_estimate INTEGER,
                content_hash TEXT,
                FOREIGN KEY (source_id) REFERENCES context_sources(id)
            );

            CREATE TABLE IF NOT EXISTS context_chunks (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                level INTEGER NOT NULL,
                kind TEXT NOT NULL,
                text TEXT NOT NULL,
                token_estimate INTEGER,
                source_references_json TEXT NOT NULL,
                content_hash TEXT,
                is_stale INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                FOREIGN KEY (source_id) REFERENCES context_sources(id)
            );

            CREATE INDEX IF NOT EXISTS idx_context_chunks_source_level
            ON context_chunks(source_id, level);

            CREATE INDEX IF NOT EXISTS idx_context_chunks_stale
            ON context_chunks(is_stale);

            CREATE TABLE IF NOT EXISTS context_snapshots (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                summary TEXT NOT NULL,
                token_estimate INTEGER,
                built_through_reference_json TEXT,
                source_references_json TEXT NOT NULL,
                content_hash TEXT,
                created_at REAL NOT NULL,
                FOREIGN KEY (source_id) REFERENCES context_sources(id)
            );

            CREATE TABLE IF NOT EXISTS memory_items (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                text TEXT NOT NULL,
                source_references_json TEXT NOT NULL,
                confidence TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                FOREIGN KEY (source_id) REFERENCES context_sources(id)
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS context_search USING fts5(
                source_id UNINDEXED,
                record_id UNINDEXED,
                record_type UNINDEXED,
                title,
                body,
                tokenize = 'unicode61'
            );
            """)
        }
        try migrator.migrate(dbQueue)
    }

    private func upsertSearch(
        _ db: Database,
        sourceID: UUID,
        recordID: UUID,
        recordType: ContextSearchRecordType,
        title: String?,
        body: String
    ) throws {
        try db.execute(
            sql: "DELETE FROM context_search WHERE record_id = ? AND record_type = ?",
            arguments: [recordID.uuidString, recordType.rawValue]
        )
        try db.execute(
            sql: """
            INSERT INTO context_search (source_id, record_id, record_type, title, body)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [sourceID.uuidString, recordID.uuidString, recordType.rawValue, title, body]
        )
    }

    private func decodeSource(_ row: Row) throws -> ContextSource {
        ContextSource(
            id: try uuid(row["id"]),
            kind: ContextSourceKind(rawValue: row["kind"])!,
            title: row["title"],
            contentHash: row["content_hash"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"]),
            metadata: try decodeJSON(row["metadata_json"])
        )
    }

    private func decodeTurn(_ row: Row) throws -> ConversationTurn {
        ConversationTurn(
            id: try uuid(row["id"]),
            sourceID: try uuid(row["source_id"]),
            turnIndex: row["turn_index"],
            role: LLMRole(rawValue: row["role"])!,
            content: row["content"],
            tokenEstimate: row["token_estimate"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            metadata: try decodeJSON(row["metadata_json"])
        )
    }

    private func decodeChunk(_ row: Row) throws -> ContextChunk {
        ContextChunk(
            id: try uuid(row["id"]),
            sourceID: try uuid(row["source_id"]),
            level: row["level"],
            kind: ContextChunkKind(rawValue: row["kind"])!,
            text: row["text"],
            tokenEstimate: row["token_estimate"],
            sourceReferences: try decodeJSON(row["source_references_json"]),
            contentHash: row["content_hash"],
            isStale: (row["is_stale"] as Int) != 0,
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
    }

    private func decodeSnapshot(_ row: Row) throws -> ConversationSnapshot {
        ConversationSnapshot(
            id: try uuid(row["id"]),
            sourceID: try uuid(row["source_id"]),
            summary: row["summary"],
            tokenEstimate: row["token_estimate"],
            builtThroughReference: try decodeOptionalJSON(row["built_through_reference_json"]),
            sourceReferences: try decodeJSON(row["source_references_json"]),
            contentHash: row["content_hash"],
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }

    private func decodeSearchResult(_ row: Row) throws -> ContextSearchResult {
        ContextSearchResult(
            sourceID: try uuid(row["source_id"]),
            recordID: try uuid(row["record_id"]),
            recordType: ContextSearchRecordType(rawValue: row["record_type"])!,
            title: row["title"],
            text: row["body"]
        )
    }

    private func uuid(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw ContextStoreError.invalidUUID(value)
        }
        return uuid
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        String(data: try encoder.encode(value), encoding: .utf8) ?? ""
    }

    private func decodeJSON<T: Decodable>(_ value: String) throws -> T {
        try decoder.decode(T.self, from: Data(value.utf8))
    }

    private func decodeOptionalJSON<T: Decodable>(_ value: String?) throws -> T? {
        guard let value, !value.isEmpty, value != "null" else {
            return nil
        }
        return try decodeJSON(value)
    }
}

public enum ContextStoreError: Error, Hashable, Sendable {
    case invalidUUID(String)
}
