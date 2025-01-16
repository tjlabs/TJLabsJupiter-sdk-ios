import Foundation
import SystemConfiguration
import TJLabsCommon

class JupiterNetworkManager {
    static let shared = JupiterNetworkManager()
    
    private let reachability = SCNetworkReachabilityCreateWithName(nil, "NetworkCheck")
    
    private let rfdSessions: [URLSession]
    private let uvdSessions: [URLSession]
    private let fltSessions: [URLSession]
    
    private var rfdSessionCount = 0
    private var uvdSessionCount = 0
    private var fltSessionCount = 0

    private init() {
        self.rfdSessions = JupiterNetworkManager.createSessionPool()
        self.uvdSessions = JupiterNetworkManager.createSessionPool()
        self.fltSessions = JupiterNetworkManager.createSessionPool()
    }
    
    func isConnectedToInternet() -> (Bool, String) {
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(self.reachability!, &flags)
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        if isReachable && !needsConnection {
            return (true, "")
        } else {
            return (false, "Network Connection Fail, Check Wifi of Cellular connection")
        }
    }
    
    // MARK: - Helper Methods
    private static func createSessionPool() -> [URLSession] {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = TIMEOUT_VALUE_PUT
        config.timeoutIntervalForRequest = TIMEOUT_VALUE_PUT
        return (1...3).map { _ in URLSession(configuration: config) }
    }

    private func encodeJson<T: Encodable>(_ param: T) -> Data? {
        do {
            return try JSONEncoder().encode(param)
        } catch {
            print("Error encoding JSON: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeRequest(url: String, method: String = "POST", body: Data?) -> URLRequest? {
        guard let url = URL(string: url) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        }
        return request
    }

    private func performRequest<T>(
        request: URLRequest,
        session: URLSession,
        input: T,
        completion: @escaping (Int, String, T) -> Void
    ) {
        session.dataTask(with: request) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500

            // Handle errors
            if let error = error {
                let message = (error as? URLError)?.code == .timedOut ? "Timed out" : error.localizedDescription
                DispatchQueue.main.async {
                    completion(code, message, input)
                }
                return
            }

            // Validate response status code
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
                let message = (response as? HTTPURLResponse)?.description ?? "Request failed"
                DispatchQueue.main.async {
                    completion(code, message, input)
                }
                return
            }

            // Successful response
            let resultData = String(data: data ?? Data(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(statusCode, resultData, input)
            }
        }.resume()
    }
    
    // MARK: - Public Methods
    func postUserLogin(url: String, input: LoginInput, completion: @escaping (Int, String) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON") }
            return
        }

        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500

            if let error = error {
                DispatchQueue.main.async {
                    completion(code, error.localizedDescription)
                }
                return
            }

            let successRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successRange.contains(statusCode) else {
                DispatchQueue.main.async {
                    completion(code, "Request failed")
                }
                return
            }

            let resultData = String(data: data ?? Data(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(statusCode, resultData)
            }
        }.resume()
    }

    func postReceivedForce(url: String, input: [ReceivedForce], completion: @escaping (Int, String, [ReceivedForce]) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }

        let session = rfdSessions[rfdSessionCount % rfdSessions.count]
        rfdSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }

    func postUserVelocity(url: String, input: [UserVelocity], completion: @escaping (Int, String, [UserVelocity]) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }

        let session = uvdSessions[uvdSessionCount % uvdSessions.count]
        uvdSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postFLT(url: String, input: FLT, completion: @escaping (Int, String, FLT) -> Void) {
        let fltInput = input.fltInput
        guard let body = encodeJson(fltInput),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let session = fltSessions[fltSessionCount % fltSessions.count]
        fltSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
}
