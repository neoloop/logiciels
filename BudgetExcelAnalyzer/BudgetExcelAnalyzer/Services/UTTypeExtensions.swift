import UniformTypeIdentifiers

extension UTType {
    /// The Office Open XML spreadsheet UTI (.xlsx) — the only format the app can actually parse.
    static let excelWorkbook = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")
    static let xlsxExtension = UTType(filenameExtension: "xlsx") ?? .data

    /// The legacy binary Excel 97-2003 UTI (.xls). CoreXLSX can't read this format, but we
    /// still let the picker show/select it so the app can show a clear "convert to .xlsx"
    /// error instead of the file just being greyed out with no explanation.
    static let legacyExcelWorkbook = UTType(importedAs: "com.microsoft.excel.xls")
    static let xlsExtension = UTType(filenameExtension: "xls") ?? .data
}
