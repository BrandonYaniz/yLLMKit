import Foundation
import yLLMKit

public struct ContextSource: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var kind: ContextSourceKind
    public var title: String?
    public var contentHash: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: [String: String]

    public init(
        id: ID = UUID(),
        kind: ContextSourceKind,
        title: String? = nil,
        contentHash: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public enum ContextSourceKind: String, Codable, Hashable, Sendable {
    case conversation
    case plainTextDocument
    case markdownDocument
}

public struct ConversationTurn: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var turnIndex: Int
    public var role: LLMRole
    public var content: String
    public var tokenEstimate: Int?
    public var createdAt: Date
    public var metadata: [String: String]

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        turnIndex: Int,
        role: LLMRole,
        content: String,
        tokenEstimate: Int? = nil,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sourceID = sourceID
        self.turnIndex = turnIndex
        self.role = role
        self.content = content
        self.tokenEstimate = tokenEstimate
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct ContextSourceSpan: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var startOffset: Int
    public var endOffset: Int
    public var sectionTitle: String?
    public var text: String?
    public var tokenEstimate: Int?
    public var contentHash: String?

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        startOffset: Int,
        endOffset: Int,
        sectionTitle: String? = nil,
        text: String? = nil,
        tokenEstimate: Int? = nil,
        contentHash: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.sectionTitle = sectionTitle
        self.text = text
        self.tokenEstimate = tokenEstimate
        self.contentHash = contentHash
    }
}

public struct ContextChunk: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var level: Int
    public var kind: ContextChunkKind
    public var text: String
    public var tokenEstimate: Int?
    public var sourceReferences: [ContextSourceReference]
    public var contentHash: String?
    public var isStale: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        level: Int,
        kind: ContextChunkKind,
        text: String,
        tokenEstimate: Int? = nil,
        sourceReferences: [ContextSourceReference] = [],
        contentHash: String? = nil,
        isStale: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.level = level
        self.kind = kind
        self.text = text
        self.tokenEstimate = tokenEstimate
        self.sourceReferences = sourceReferences
        self.contentHash = contentHash
        self.isStale = isStale
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ContextChunkKind: String, Codable, Hashable, Sendable {
    case raw
    case summary
    case snapshot
    case memory
}

public struct ContextChunkLink: Codable, Hashable, Sendable {
    public var parentChunkID: ContextChunk.ID
    public var childChunkID: ContextChunk.ID
    public var position: Int

    public init(
        parentChunkID: ContextChunk.ID,
        childChunkID: ContextChunk.ID,
        position: Int
    ) {
        self.parentChunkID = parentChunkID
        self.childChunkID = childChunkID
        self.position = position
    }
}

public struct ContextSourceReference: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var kind: ContextSourceReferenceKind
    public var targetID: UUID?
    public var startOffset: Int?
    public var endOffset: Int?
    public var label: String?

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        kind: ContextSourceReferenceKind,
        targetID: UUID? = nil,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.kind = kind
        self.targetID = targetID
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.label = label
    }
}

public enum ContextSourceReferenceKind: String, Codable, Hashable, Sendable {
    case source
    case turn
    case span
    case chunk
    case snapshot
    case memoryItem
}

public struct MemoryItem: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var kind: MemoryItemKind
    public var text: String
    public var sourceReferences: [ContextSourceReference]
    public var confidence: MemoryConfidence
    public var status: MemoryItemStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        kind: MemoryItemKind,
        text: String,
        sourceReferences: [ContextSourceReference] = [],
        confidence: MemoryConfidence = .medium,
        status: MemoryItemStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.kind = kind
        self.text = text
        self.sourceReferences = sourceReferences
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum MemoryItemKind: String, Codable, Hashable, Sendable {
    case fact
    case preference
    case summary
    case decision
}

public enum MemoryConfidence: String, Codable, Hashable, Sendable {
    case low
    case medium
    case high
}

public enum MemoryItemStatus: String, Codable, Hashable, Sendable {
    case active
    case stale
    case archived
}

public struct ConversationSnapshot: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var sourceID: ContextSource.ID
    public var summary: String
    public var tokenEstimate: Int?
    public var builtThroughReference: ContextSourceReference?
    public var sourceReferences: [ContextSourceReference]
    public var contentHash: String?
    public var createdAt: Date

    public init(
        id: ID = UUID(),
        sourceID: ContextSource.ID,
        summary: String,
        tokenEstimate: Int? = nil,
        builtThroughReference: ContextSourceReference? = nil,
        sourceReferences: [ContextSourceReference] = [],
        contentHash: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.summary = summary
        self.tokenEstimate = tokenEstimate
        self.builtThroughReference = builtThroughReference
        self.sourceReferences = sourceReferences
        self.contentHash = contentHash
        self.createdAt = createdAt
    }
}

public struct ContextBudget: Codable, Hashable, Sendable {
    public var maximumInputTokens: Int
    public var reservedOutputTokens: Int
    public var maximumInstructionTokens: Int?
    public var maximumRecentTurnTokens: Int?
    public var maximumSnapshotTokens: Int?
    public var maximumRetrievedSourceTokens: Int?

    public var availableInputTokens: Int {
        max(0, maximumInputTokens - reservedOutputTokens)
    }

    public init(
        maximumInputTokens: Int,
        reservedOutputTokens: Int,
        maximumInstructionTokens: Int? = nil,
        maximumRecentTurnTokens: Int? = nil,
        maximumSnapshotTokens: Int? = nil,
        maximumRetrievedSourceTokens: Int? = nil
    ) {
        self.maximumInputTokens = maximumInputTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.maximumInstructionTokens = maximumInstructionTokens
        self.maximumRecentTurnTokens = maximumRecentTurnTokens
        self.maximumSnapshotTokens = maximumSnapshotTokens
        self.maximumRetrievedSourceTokens = maximumRetrievedSourceTokens
    }
}

public struct PreparedContext: Codable, Hashable, Sendable {
    public var messages: [LLMMessage]
    public var estimatedInputTokens: Int?
    public var includedReferences: [ContextSourceReference]
    public var omittedReferences: [ContextSourceReference]
    public var warnings: [ContextBuildWarning]
    public var metadata: [String: String]

    public init(
        messages: [LLMMessage],
        estimatedInputTokens: Int? = nil,
        includedReferences: [ContextSourceReference] = [],
        omittedReferences: [ContextSourceReference] = [],
        warnings: [ContextBuildWarning] = [],
        metadata: [String: String] = [:]
    ) {
        self.messages = messages
        self.estimatedInputTokens = estimatedInputTokens
        self.includedReferences = includedReferences
        self.omittedReferences = omittedReferences
        self.warnings = warnings
        self.metadata = metadata
    }
}

public struct ContextBuildWarning: Codable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var kind: ContextBuildWarningKind
    public var message: String
    public var sourceReference: ContextSourceReference?

    public init(
        id: ID = UUID(),
        kind: ContextBuildWarningKind,
        message: String,
        sourceReference: ContextSourceReference? = nil
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.sourceReference = sourceReference
    }
}

public enum ContextBuildWarningKind: String, Codable, Hashable, Sendable {
    case tokenBudgetExceeded
    case sourceOmitted
    case staleSnapshot
    case missingSourceText
}

public enum ContextRebuildPolicy: String, Codable, Hashable, Sendable {
    case automatic
    case manual
    case disabled
}

public enum ContextPowerPolicy: String, Codable, Hashable, Sendable {
    case alwaysAllow
    case reduceOnBattery
    case disableRebuildsOnBattery
    case deterministicOnly
}
