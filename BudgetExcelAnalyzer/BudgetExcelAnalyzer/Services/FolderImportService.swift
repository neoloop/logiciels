import Foundation

/// Scans a folder for the app's three Excel sources (budget, commandes/PPI, Sedit) by
/// *content*, not filename: each .xlsx found is tried against the three existing import
/// services in turn, and whichever one parses successfully tells us what the file is.
/// This is more robust than filename keyword matching since real-world naming varies.
enum FolderImportService {

    struct ClassifiedFiles {
        var budgetFileURL: URL?
        var commandesFileURL: URL?
        var seditFileURL: URL?
        var unrecognizedFileNames: [String] = []
    }

    static func classifyFiles(in folderURL: URL) throws -> ClassifiedFiles {
        var result = ClassifiedFiles()

        let contents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let xlsxFiles = contents.filter { $0.pathExtension.lowercased() == "xlsx" }

        for fileURL in xlsxFiles {
            let coordinated = coordinatedURL(for: fileURL)

            if result.budgetFileURL == nil, (try? ExcelImportService.importWorkbook(at: coordinated)) != nil {
                result.budgetFileURL = fileURL
            } else if result.commandesFileURL == nil, (try? CommandesImportService.importWorkbook(at: coordinated)) != nil {
                result.commandesFileURL = fileURL
            } else if result.seditFileURL == nil, (try? SeditImportService.importWorkbook(at: coordinated)) != nil {
                result.seditFileURL = fileURL
            } else {
                result.unrecognizedFileNames.append(fileURL.lastPathComponent)
            }
        }

        if result.budgetFileURL == nil && result.commandesFileURL == nil && result.seditFileURL == nil {
            throw ImportError.noData
        }
        return result
    }

    /// Coordinated read of a single file discovered inside an already security-scoped
    /// folder, for the same freshness reasons as the per-file stores.
    private static func coordinatedURL(for fileURL: URL) -> URL {
        var coordinatorError: NSError?
        var resolved = fileURL
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { url in
            resolved = url
        }
        return resolved
    }
}
