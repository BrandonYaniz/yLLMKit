import yLLMKit

enum MLXPromptBuilder {
    static func promptText(from messages: [LLMMessage]) -> String {
        let promptMessages = messages.filter { $0.role != .system }

        if promptMessages.count == 1, let message = promptMessages.first {
            return message.content
        }

        return promptMessages
            .map { message in
                switch message.role {
                case .user:
                    return "User: \(message.content)"
                case .assistant:
                    return "Assistant: \(message.content)"
                case .tool:
                    return "Tool: \(message.content)"
                case .system:
                    return message.content
                }
            }
            .joined(separator: "\n\n")
    }
}
