import Foundation
import NewToTownCore
import Supabase

public final class SupabaseProfileReportingService: ProfileReportingService {
    private let functions: FunctionsClient
    private let accountID: UUID

    init(
        client: SupabaseClient, accountID: UUID, configuration: SupabaseConfiguration,
        session: URLSession = .shared
    ) {
        self.accountID = accountID
        functions = accountFunctionsClient(
            client: client, accountID: accountID, configuration: configuration, session: session)
    }

    public func submit(_ report: ProfileReport) async throws -> UUID {
        guard report.isValid, report.targetID != accountID else { throw ProfileReportingError.invalidReport }
        do {
            let receipt: Receipt = try await functions.invoke(
                "reports", options: FunctionInvokeOptions(body: Command(report: report), timeoutInterval: 45))
            return receipt.id
        } catch {
            if let typed = error as? ProfileReportingError { throw typed }
            if error is AccountSessionError { throw ProfileReportingError.signedOut }
            if case FunctionsError.httpError(let status, _) = error {
                switch status {
                case 401: throw ProfileReportingError.signedOut
                case 404: throw ProfileReportingError.unavailable
                case 400: throw ProfileReportingError.invalidReport
                case 409: throw ProfileReportingError.retryConflict
                default: break
                }
            }
            throw ProfileReportingError.connection
        }
    }
}

private struct Receipt: Decodable { let id: UUID }
private struct Command: Encodable {
    let report: ProfileReport
    enum CodingKeys: String, CodingKey {
        case targetID = "target_id"
        case reason, details
        case clientReportID = "client_report_id"
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(report.targetID, forKey: .targetID)
        try values.encode(report.retryID, forKey: .clientReportID)
        try values.encode(report.reason.rawValue, forKey: .reason)
        try values.encode(report.details, forKey: .details)
    }
}
