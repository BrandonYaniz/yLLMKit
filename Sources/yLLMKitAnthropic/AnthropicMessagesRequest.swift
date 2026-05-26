import Foundation
import yLLMKit

struct AnthropicMessagesRequest: Encodable {
    var model: String
    var messages: [AnthropicMessage]
    var system: String?
    var stream: Bool
    var maxTokens: Int
    var temperature: Double?
    var topP: Double?
    var stopSequences: [String]?
    var extra: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case system
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stopSequences = "stop_sequences"
    }

    init(_ request: LLMChatRequest) {
        self.model = request.modelID.modelName
        self.messages = request.messages
            .filter { $0.role != .system }
            .map(AnthropicMessage.init)
        self.system = request.messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .nilIfEmpty
        self.stream = true
        self.maxTokens = request.settings.maxOutputTokens ?? 1024
        self.temperature = request.settings.temperature
        self.topP = request.settings.topP
        self.stopSequences = request.settings.stopSequences.isEmpty ? nil : request.settings.stopSequences
        self.extra = request.providerOptions.values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(system, forKey: .system)
        try container.encode(stream, forKey: .stream)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(stopSequences, forKey: .stopSequences)

        var extraContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in extra where CodingKeys(stringValue: key) == nil {
            try extraContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
        }
    }
}

struct AnthropicMessage: Encodable {
    var role: String
    var content: String

    init(_ message: LLMMessage) {
        switch message.role {
        case .assistant:
            self.role = "assistant"
        case .system, .user:
            self.role = "user"
        }
        self.content = message.content
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
