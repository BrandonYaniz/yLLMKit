import Foundation

public enum FileModelRemovalPolicy: Sendable {
    case storeRootOnly
    case registeredPaths
}

public actor FileModelStore: ModelStore {
    public let rootDirectory: URL
    public let removalPolicy: FileModelRemovalPolicy

    private let indexURL: URL
    private let fileManager: FileManager
    private var modelsByID: [String: LocalModel]

    public init(
        rootDirectory: URL,
        removalPolicy: FileModelRemovalPolicy = .storeRootOnly,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.removalPolicy = removalPolicy
        self.indexURL = rootDirectory.appendingPathComponent("models.json")
        self.fileManager = fileManager

        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            let models = try JSONDecoder().decode([LocalModel].self, from: data)
            self.modelsByID = Dictionary(uniqueKeysWithValues: models.map { ($0.modelID, $0) })
        } else {
            self.modelsByID = [:]
        }
    }

    public func localModels() -> [LocalModel] {
        modelsByID.values.sorted { $0.modelID < $1.modelID }
    }

    public func localModel(for modelID: String) -> LocalModel? {
        modelsByID[modelID]
    }

    public func isModelInstalled(_ modelID: String) -> Bool {
        guard let model = modelsByID[modelID] else {
            return false
        }
        return fileManager.fileExists(atPath: model.path)
    }

    public func register(_ model: LocalModel) throws {
        var storedModel = model
        if storedModel.sizeBytes == nil {
            storedModel.sizeBytes = try sizeOfItem(at: URL(fileURLWithPath: storedModel.path))
        }

        modelsByID[storedModel.modelID] = storedModel
        try saveIndex()
    }

    public func removeModel(id modelID: String) throws {
        guard let model = modelsByID.removeValue(forKey: modelID) else {
            return
        }

        let modelURL = URL(fileURLWithPath: model.path)
        if shouldRemoveFiles(at: modelURL), fileManager.fileExists(atPath: modelURL.path) {
            try fileManager.removeItem(at: modelURL)
        }

        try saveIndex()
    }

    private func saveIndex() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(localModels())
        try data.write(to: indexURL, options: .atomic)
    }

    private func sizeOfItem(at url: URL) throws -> Int64? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        if resourceValues.isDirectory == true {
            return try directorySize(at: url)
        }

        return resourceValues.fileSize.map(Int64.init)
    }

    private func directorySize(at url: URL) throws -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    private func isPathInsideRoot(_ url: URL) -> Bool {
        let rootPath = rootDirectory.standardizedFileURL.path
        let itemPath = url.standardizedFileURL.path
        return itemPath == rootPath || itemPath.hasPrefix(rootPath + "/")
    }

    private func shouldRemoveFiles(at url: URL) -> Bool {
        let rootPath = rootDirectory.standardizedFileURL.path
        let itemPath = url.standardizedFileURL.path
        guard itemPath != "/", itemPath != rootPath else {
            return false
        }

        switch removalPolicy {
        case .storeRootOnly:
            return isPathInsideRoot(url)
        case .registeredPaths:
            return true
        }
    }
}
