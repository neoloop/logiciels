import XCTest
@testable import GLPIInterventions

final class FileExportRepositoryTests: XCTestCase {
    func testTicketExportEntryDecodesTicketAndFollowups() throws {
        let json = """
        {
            "id": 12,
            "name": "Onduleur en défaut",
            "content": "<p>Voyant rouge.</p>",
            "status": 2,
            "priority": 4,
            "date": "2024-03-01 08:00:00",
            "date_mod": "2024-03-01 09:00:00",
            "followups": [
                { "id": 1, "content": "Pris en charge.", "date": "2024-03-01 09:00:00", "is_private": 0 }
            ]
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(TicketExportEntry.self, from: json)

        XCTAssertEqual(entry.ticket.id, 12)
        XCTAssertEqual(entry.ticket.name, "Onduleur en défaut")
        XCTAssertEqual(entry.ticket.status, .processingAssigned)
        XCTAssertEqual(entry.followups.count, 1)
        XCTAssertEqual(entry.followups.first?.content, "Pris en charge.")
    }

    func testTicketExportFileDecodesMultipleTicketsAndGeneratedAt() throws {
        let json = """
        {
            "generated_at": "2024-03-01 10:00:00",
            "tickets": [
                { "id": 1, "name": "A", "content": "", "status": 1, "priority": 3, "date": null, "date_mod": null, "followups": [] },
                { "id": 2, "name": "B", "content": "", "status": 6, "priority": 1, "date": null, "date_mod": null, "followups": [] }
            ]
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(TicketExportFile.self, from: json)

        XCTAssertNotNil(file.generatedAt)
        XCTAssertEqual(file.tickets.count, 2)
        XCTAssertEqual(file.tickets.map(\.ticket.id), [1, 2])
    }

    func testFetchTicketSummariesExcludesClosedByDefault() async throws {
        let json = """
        {
            "generated_at": "2024-03-01 10:00:00",
            "tickets": [
                { "id": 1, "name": "Ouvert", "content": "", "status": 1, "priority": 3, "date": null, "date_mod": "2024-03-01 09:00:00", "followups": [] },
                { "id": 2, "name": "Clos", "content": "", "status": 6, "priority": 1, "date": null, "date_mod": "2024-03-01 08:00:00", "followups": [] }
            ]
        }
        """.data(using: .utf8)!

        let session = URLSession.stubbed(data: json, statusCode: 200)
        let repository = FileExportRepository(fileURL: URL(string: "https://example.com/export.json")!, urlSession: session)

        let openOnly = try await repository.fetchTicketSummaries(includeClosed: false)
        XCTAssertEqual(openOnly.map(\.id), [1])

        let all = try await repository.fetchTicketSummaries(includeClosed: true)
        XCTAssertEqual(Set(all.map(\.id)), Set([1, 2]))
        XCTAssertNotNil(repository.lastSyncedAt)
    }

    func testWriteOperationsThrowReadOnly() async {
        let repository = FileExportRepository(fileURL: URL(string: "https://example.com/export.json")!)

        await XCTAssertThrowsErrorAsync(try await repository.updateTicketStatus(id: 1, status: .solved))
        await XCTAssertThrowsErrorAsync(try await repository.addFollowup(ticketId: 1, content: "test"))
    }
}

// MARK: - Test helpers

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        // expected
    }
}

private final class StubURLProtocol: URLProtocol {
    static var stubData: Data = Data()
    static var stubStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.stubStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.stubData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func stubbed(data: Data, statusCode: Int) -> URLSession {
        StubURLProtocol.stubData = data
        StubURLProtocol.stubStatusCode = statusCode
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
