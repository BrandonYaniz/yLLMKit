import Foundation
import yLLMKit

struct OpenAIChatCompletionRequest: Encodable {
    var model: String
    var messages: [OpenAIChatMessage]
    var stream: Bool
    var streamOptions: OpenAIStreamOptions
    var temperature: Double?
    var topP: Double?
    var maxTokens: Int?
    var stop: [String]?
    var extra: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case streamOptions = "stream_options"
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stop
    }

    init(_ request: LLMChatRequest) {
        self.model = request.modelID.modelName
        self.messages = request.messages.map(OpenAIChatMessage.init)
        self.stream = true
        self.streamOptions = OpenAIStreamOptions(includeUsage: true)
        self.temperature = request.settings.temperature
        self.topP = request.settings.topP
        self.maxTokens = request.settings.maxOutputTokens
        self.stop = request.settings.stopSequences.isEmpty ? nil : request.settings.stopSequences
        self.extra = request.providerOptions.values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encode(streamOptions, forKey: .streamOptions)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(stop, forKey: .stop)

        var extraContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in extra where CodingKeys(stringValue: key) == nil {
            try extraContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
        }
    }
}

struct OpenAIChatMessage: Encodable {
    var role: String
    var content: String

    init(_ message: LLMMessage) {
        switch message.role {
        case .system:
            self.role = "system"
        case .user:
            self.role = "user"
        case .assistant:
            self.role = "assistant"
        }
        self.content = message.content
    }
}

struct OpenAIStreamOptions: Encodable {
    var includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
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
