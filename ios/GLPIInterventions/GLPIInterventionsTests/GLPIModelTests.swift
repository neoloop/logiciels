import XCTest
@testable import GLPIInterventions

final class GLPIModelTests: XCTestCase {
    func testTicketStatusLabels() {
        XCTAssertEqual(TicketStatus(rawValue: 1), .new)
        XCTAssertEqual(TicketStatus(rawValue: 6), .closed)
        XCTAssertNil(TicketStatus(rawValue: 99))
    }

    func testTicketSummaryBuildsFromSearchRow() {
        let mapping = GLPIFieldMapping.default
        let row: [String: JSONValue] = [
            mapping.idField: .int(42),
            mapping.titleField: .string("Imprimante en panne"),
            mapping.statusField: .int(2),
            mapping.priorityField: .int(4),
            mapping.dateField: .string("2024-01-15 10:30:00"),
            mapping.dateModField: .string("2024-01-16 08:00:00")
        ]

        let summary = TicketSummary(row: row, mapping: mapping)

        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.id, 42)
        XCTAssertEqual(summary?.title, "Imprimante en panne")
        XCTAssertEqual(summary?.status, .processingAssigned)
        XCTAssertEqual(summary?.priority, .high)
        XCTAssertNotNil(summary?.date)
        XCTAssertNotNil(summary?.dateMod)
    }

    func testTicketSummaryFailsWithoutId() {
        let mapping = GLPIFieldMapping.default
        let row: [String: JSONValue] = [
            mapping.titleField: .string("Sans identifiant")
        ]
        XCTAssertNil(TicketSummary(row: row, mapping: mapping))
    }

    func testTicketDecodingFromGLPIItemJSON() throws {
        let json = """
        {
            "id": 7,
            "name": "Écran cassé",
            "content": "<p>L'écran ne s'allume plus.</p>",
            "status": 5,
            "priority": 3,
            "date": "2024-02-01 09:00:00",
            "date_mod": "2024-02-02 11:00:00"
        }
        """.data(using: .utf8)!

        let ticket = try JSONDecoder().decode(Ticket.self, from: json)

        XCTAssertEqual(ticket.id, 7)
        XCTAssertEqual(ticket.name, "Écran cassé")
        XCTAssertEqual(ticket.status, .solved)
        XCTAssertEqual(ticket.priority, .medium)
    }

    func testHTMLTextStripsTagsAndEntities() {
        let html = "<p>Bonjour&nbsp;&amp; bienvenue.<br/>Ligne 2</p>"
        let plain = HTMLText.plainText(from: html)
        XCTAssertEqual(plain, "Bonjour & bienvenue.\nLigne 2")
    }

    func testGLPIConfigBuildsAPIBaseURL() {
        let config = GLPIConfig(
            serverURL: URL(string: "https://glpi.example.com")!,
            appToken: "app-token",
            userToken: "user-token"
        )
        XCTAssertEqual(config.apiBaseURL.absoluteString, "https://glpi.example.com/apirest.php")
    }
}
