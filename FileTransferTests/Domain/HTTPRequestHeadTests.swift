import Foundation
import Testing
@testable import FileTransfer

struct HTTPRequestHeadTests {

    private func head(_ text: String) -> HTTPRequestHead? {
        HTTPRequestHead(parsing: Data(text.utf8))
    }

    @Test func parsesWellFormedPut() {
        let parsed = head("PUT /v1/transfer HTTP/1.1\r\nContent-Length: 42\r\nX-FT-Transfer-ID: abc\r\n")
        #expect(parsed?.method == "PUT")
        #expect(parsed?.path == "/v1/transfer")
        #expect(parsed?.contentLength == 42)
        #expect(parsed?.headers["x-ft-transfer-id"] == "abc")
    }

    @Test func headerNamesAreLowercased_valuesPreserved() {
        let parsed = head("PUT / HTTP/1.1\r\nX-Mixed-CASE: ValUe\r\n")
        #expect(parsed?.headers["x-mixed-case"] == "ValUe")
    }

    @Test func toleratesBareNewlines() {
        let parsed = head("PUT /v1/transfer HTTP/1.1\nContent-Length: 7\n")
        #expect(parsed?.contentLength == 7)
    }

    @Test func lowercaseMethodIsNormalized() {
        #expect(head("put / HTTP/1.1\r\n")?.method == "PUT")
    }

    @Test func rejectsMalformedRequestLine() {
        #expect(head("PUT/v1/transfer HTTP/1.1\r\n") == nil)
        #expect(head("PUT /v1/transfer\r\n") == nil)
        #expect(head("PUT /v1/transfer SPDY/3\r\n") == nil)
        #expect(head("") == nil)
    }

    @Test func rejectsHeaderLineWithoutColon() {
        #expect(head("PUT / HTTP/1.1\r\nNotAHeader\r\n") == nil)
    }

    @Test func missingContentLength_isNilNotZero() {
        let parsed = head("PUT /v1/transfer HTTP/1.1\r\nX-FT-Transfer-ID: abc\r\n")
        #expect(parsed != nil)
        #expect(parsed?.contentLength == nil)
    }

    @Test func negativeContentLength_isRejected() {
        #expect(head("PUT / HTTP/1.1\r\nContent-Length: -5\r\n")?.contentLength == nil)
    }

    @Test func headTerminator_foundAndSplitsCorrectly() {
        let buffer = Data("PUT / HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc".utf8)
        let range = HTTPRequestHead.headTerminatorRange(in: buffer)
        #expect(range != nil)
        if let range {
            let headData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            let body = buffer.subdata(in: range.upperBound..<buffer.endIndex)
            #expect(HTTPRequestHead(parsing: headData) != nil)
            #expect(String(data: body, encoding: .utf8) == "abc")
        }
    }

    @Test func headTerminator_absentInPartialHead() {
        #expect(HTTPRequestHead.headTerminatorRange(in: Data("PUT / HTTP/1.1\r\nContent-".utf8)) == nil)
    }
}
