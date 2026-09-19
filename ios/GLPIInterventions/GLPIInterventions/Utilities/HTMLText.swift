import Foundation

/// GLPI stores ticket/followup content as HTML. Rendering it in a full web
/// view is overkill for a mobile detail screen, so we strip tags and decode
/// entities to get readable plain text.
enum HTMLText {
    static func plainText(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#039;", with: "'")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
