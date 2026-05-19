import MLXLMCommon
import yLLMKit

enum MLXPromptBuilder {
    struct PromptRequest {
        var instructions: String?
        var history: [Chat.Message]
        var prompt: Chat.Message
    }

    static func promptRequest(from messages: [LLMMessage]) throws -> PromptRequest {
        let instructions = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
        let chatMessages = messages
            .filter { $0.role != .system }
            .map(chatMessage)

        guard let prompt = chatMessages.last else {
            throw LLMError.invalidRequest("At least one non-system message is required.")
        }

        return PromptRequest(
            instructions: instructions.isEmpty ? nil : instructions,
            history: Array(chatMessages.dropLast()),
            prompt: prompt
        )
    }

    private static func chatMessage(from message: LLMMessage) -> Chat.Message {
        Chat.Message(
            role: chatRole(from: message.role),
            content: message.content
        )
    }

    private static func chatRole(from role: LLMMessage.Role) -> Chat.Message.Role {
        switch role {
        case .system:
            return .system
        case .user:
            return .user
        case .assistant:
            return .assistant
        case .tool:
            return .tool
        }
    }
}
