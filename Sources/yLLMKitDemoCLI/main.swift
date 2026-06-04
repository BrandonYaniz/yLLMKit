import Darwin
import Foundation
import yLLMKit
import yLLMKitAnthropic
import yLLMKitMLX
import yLLMKitOpenAI

@main
struct DemoCLI {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(arguments: [String]) async throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "list-mlx-models":
            try await listMLXModels()
        case "prepare-mlx":
            try await prepareMLX(arguments: Array(arguments.dropFirst()))
        case "chat-mlx":
            try await chatMLX(arguments: Array(arguments.dropFirst()))
        case "chat-openai":
            try await chatOpenAI(arguments: Array(arguments.dropFirst()))
        case "chat-anthropic":
            try await chatAnthropic(arguments: Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            printUsage()
        default:
            printUsage()
            throw CLIError.unknownCommand(command)
        }
    }

    private static func listMLXModels() async throws {
        let provider = MLXProvider()
        let models = try await provider.availableModels()

        for model in models {
            let contextWindow = model.capabilities.contextWindow.map(String.init) ?? "unknown"
            let outputTokens = model.capabilities.maxOutputTokens.map(String.init) ?? "unknown"
            print("\(model.id.description)\t\(model.displayName)\tcontext=\(contextWindow)\tmaxOutput=\(outputTokens)")
        }
    }

    private static func prepareMLX(arguments: [String]) async throws {
        let modelID = try mlxModelID(arguments)
        let provider = MLXProvider()

        for try await progress in provider.prepareModelWithProgress(modelID) {
            printProgress(progress)
        }
    }

    private static func chatMLX(arguments: [String]) async throws {
        let (modelID, prompt) = try modelAndPrompt(arguments, providerID: "mlx")
        let provider = MLXProvider()
        try await streamChat(provider: provider, modelID: modelID, prompt: prompt, shouldPrepare: true)
    }

    private static func chatOpenAI(arguments: [String]) async throws {
        let apiKey = try environment("OPENAI_API_KEY")
        let (modelID, prompt) = try modelAndPrompt(arguments, providerID: "openai")
        let provider = OpenAIProvider(configuration: OpenAIProviderConfiguration(apiKey: apiKey))
        try await streamChat(provider: provider, modelID: modelID, prompt: prompt, shouldPrepare: true)
    }

    private static func chatAnthropic(arguments: [String]) async throws {
        let apiKey = try environment("ANTHROPIC_API_KEY")
        let (modelID, prompt) = try modelAndPrompt(arguments, providerID: "anthropic")
        let provider = AnthropicProvider(configuration: AnthropicProviderConfiguration(apiKey: apiKey))
        try await streamChat(provider: provider, modelID: modelID, prompt: prompt, shouldPrepare: true)
    }

    private static func streamChat(
        provider: any LLMProvider,
        modelID: LLMModelID,
        prompt: String,
        shouldPrepare: Bool
    ) async throws {
        if shouldPrepare {
            try await provider.prepareModel(modelID)
        }

        let request = LLMChatRequest(
            modelID: modelID,
            messages: [
                LLMMessage(role: .system, content: "Answer clearly and concisely."),
                LLMMessage(role: .user, content: prompt)
            ],
            settings: GenerationSettings(
                temperature: 0.2,
                topP: 0.9,
                maxOutputTokens: 256
            )
        )

        for try await event in provider.streamChat(request: request) {
            switch event {
            case .started:
                break
            case .textDelta(let text):
                print(text, terminator: "")
                fflush(stdout)
            case .completed(let response):
                print("")
                print("finishReason=\(response.finishReason?.rawValue ?? "unknown")")
                if let usage = response.usage {
                    print("usage input=\(usage.inputTokens?.description ?? "unknown") output=\(usage.outputTokens?.description ?? "unknown") total=\(usage.totalTokens?.description ?? "unknown")")
                }
            }
        }
    }

    private static func mlxModelID(_ arguments: [String]) throws -> LLMModelID {
        guard let modelName = arguments.first else {
            throw CLIError.missingArgument("model")
        }
        return LLMModelID(providerID: LLMProviderID(rawValue: "mlx"), modelName: modelName)
    }

    private static func modelAndPrompt(
        _ arguments: [String],
        providerID: String
    ) throws -> (LLMModelID, String) {
        guard arguments.count >= 2 else {
            throw CLIError.missingArgument("model and prompt")
        }

        let modelID = LLMModelID(
            providerID: LLMProviderID(rawValue: providerID),
            modelName: arguments[0]
        )
        let prompt = arguments.dropFirst().joined(separator: " ")
        return (modelID, prompt)
    }

    private static func environment(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CLIError.missingEnvironment(key)
        }
        return value
    }

    private static func printProgress(_ progress: ModelDownloadProgress) {
        let fraction = progress.fractionCompleted.map { String(format: "%.0f%%", $0 * 100) } ?? "unknown"
        let message = progress.message.map { " \($0)" } ?? ""
        print("\(progress.modelID)\t\(progress.phase.rawValue)\t\(fraction)\(message)")
    }

    private static func printUsage() {
        print(
            """
            yLLMKitDemoCLI

            Commands:
              list-mlx-models
              prepare-mlx <model>
              chat-mlx <model> <prompt>
              chat-openai <model> <prompt>       Requires OPENAI_API_KEY
              chat-anthropic <model> <prompt>   Requires ANTHROPIC_API_KEY
            """
        )
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case missingArgument(String)
    case missingEnvironment(String)
    case unknownCommand(String)

    var description: String {
        switch self {
        case .missingArgument(let value):
            "Missing argument: \(value)"
        case .missingEnvironment(let key):
            "Missing environment variable: \(key)"
        case .unknownCommand(let command):
            "Unknown command: \(command)"
        }
    }
}
