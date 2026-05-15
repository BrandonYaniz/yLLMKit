public enum SupportedModelCatalog {
    public static let fastLocalAssistant = ModelDescriptor(
        id: "fast-local-assistant",
        displayName: "Fast Local Assistant",
        backendID: "mlx",
        provider: "huggingface",
        repository: "mlx-community/gemma-3-1b-it-qat-4bit",
        capabilities: .chatOnly(
            contextWindow: 32768,
            preferredMaxOutputTokens: 4096
        ),
        recommendedRAMGB: 8,
        defaultSettings: GenerationSettings(
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 2048
        )
    )

    public static let phi2 = ModelDescriptor(
        id: "phi-2",
        displayName: "Phi-2",
        backendID: "mlx",
        provider: "huggingface",
        repository: "mlx-community/phi-2-hf-4bit-mlx",
        capabilities: .chatOnly(
            contextWindow: 2048,
            preferredMaxOutputTokens: 1024
        ),
        recommendedRAMGB: 8,
        defaultSettings: GenerationSettings(
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 1024
        )
    )

    public static let phi3_5Mini = ModelDescriptor(
        id: "phi-3.5-mini",
        displayName: "Phi-3.5 Mini",
        backendID: "mlx",
        provider: "huggingface",
        repository: "mlx-community/Phi-3.5-mini-instruct-4bit",
        capabilities: .chatOnly(
            contextWindow: 131072,
            preferredMaxOutputTokens: 4096
        ),
        recommendedRAMGB: 8,
        defaultSettings: GenerationSettings(
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 2048,
            stopSequences: ["<|end|>"]
        )
    )

    public static let phi3_5MoE = ModelDescriptor(
        id: "phi-3.5-moe",
        displayName: "Phi-3.5 MoE",
        backendID: "mlx",
        provider: "huggingface",
        repository: "mlx-community/Phi-3.5-MoE-instruct-4bit",
        capabilities: .chatOnly(
            contextWindow: 131072,
            preferredMaxOutputTokens: 4096
        ),
        recommendedRAMGB: 32,
        defaultSettings: GenerationSettings(
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 2048,
            stopSequences: ["<|end|>"]
        )
    )

    public static let all: [ModelDescriptor] = [
        fastLocalAssistant,
        phi2,
        phi3_5Mini,
        phi3_5MoE,
    ]
}
