import Foundation
import MLXLMCommon
import yLLMKit

public enum MLXModelConfigurationFactory {
    public static func configuration(
        for model: ModelDescriptor,
        localModel: LocalModel? = nil
    ) -> ModelConfiguration {
        if let localModel {
            return ModelConfiguration(
                directory: URL(fileURLWithPath: localModel.path),
                extraEOSTokens: Set(model.defaultSettings.stopSequences)
            )
        }

        return ModelConfiguration(
            id: model.repository,
            revision: model.revision ?? "main",
            extraEOSTokens: Set(model.defaultSettings.stopSequences)
        )
    }
}
