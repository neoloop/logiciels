import UniformTypeIdentifiers

extension UTType {
    /// The Office Open XML spreadsheet UTI (.xlsx).
    static let excelWorkbook = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")
    static let xlsxExtension = UTType(filenameExtension: "xlsx") ?? .data
}
