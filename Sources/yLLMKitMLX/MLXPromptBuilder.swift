import MLXLMCommon
import yLLMKit

enum MLXPromptBuilder {
    struct PromptRequest {
        var instructions: String?
        var history: [Chat.Message]
        var prompt: Chat.Message
    }

    static func promptRequest(from messages: [LLMMessage]) throws -> PromptRequest {
        var instructionParts: [String] = []
        var chatMessages: [Chat.Message] = []
        instructionParts.reserveCapacity(messages.count)
        chatMessages.reserveCapacity(messages.count)

        for message in messages {
            if message.role == .system {
                instructionParts.append(message.content)
            } else {
                chatMessages.append(chatMessage(from: message))
            }
        }

        guard let prompt = chatMessages.popLast() else {
            throw LLMError.invalidRequest("At least one non-system message is required.")
        }

        let instructions = instructionParts.joined(separator: "\n\n")
        return PromptRequest(
            instructions: instructions.isEmpty ? nil : instructions,
            history: chatMessages,
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
        }
    }
}
