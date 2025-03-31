import Foundation
import SystemConfiguration
import TJLabsCommon

class JupiterNetworkManager {
    static let shared = JupiterNetworkManager()
    
    private let reachability = SCNetworkReachabilityCreateWithName(nil, "NetworkCheck")
    
    private let rfdSessions: [URLSession]
    private let uvdSessions: [URLSession]
    private let umSessions:  [URLSession]
    private let mrSessions:  [URLSession]
    private let fltSessions: [URLSession]
    private let osrSessions: [URLSession]
    
    private var rfdSessionCount = 0
    private var uvdSessionCount = 0
    private var umSessionCount  = 0
    private var mrSessionCount  = 0
    private var fltSessionCount = 0
    private var osrSessionCount = 0

    private init() {
        self.rfdSessions = JupiterNetworkManager.createSessionPool()
        self.uvdSessions = JupiterNetworkManager.createSessionPool()
        self.umSessions  = JupiterNetworkManager.createSessionPool()
        self.mrSessions  = JupiterNetworkManager.createSessionPool()
        self.fltSessions = JupiterNetworkManager.createSessionPool()
        self.osrSessions = JupiterNetworkManager.createSessionPool()
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
        config.timeoutIntervalForResource = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        config.timeoutIntervalForRequest = JupiterNetworkConstants.TIMEOUT_VALUE_POST
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
    
    func postUserMask(url: String, input: [UserMask], completion: @escaping (Int, String, [UserMask]) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }

        let session = umSessions[umSessionCount % umSessions.count]
        umSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postMobileResult(url: String, input: [MobileResult], completion: @escaping (Int, String, [MobileResult]) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let session = mrSessions[mrSessionCount % mrSessions.count]
        mrSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postMobileReport(url: String, input: MobileReport, completion: @escaping (Int, String, MobileReport) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postParam(url: String, input: RcInfoSave, completion: @escaping (Int, String, RcInfoSave) -> Void) {
        guard let body = encodeJson(input),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postFLT(url: String, input: FLT, completion: @escaping (Int, String, FLT) -> Void) {
        let fltInput: FineLocationTrackingInput = input.fltInput
        guard let body = encodeJson(fltInput),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let session = fltSessions[fltSessionCount % fltSessions.count]
        fltSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postStableFLT(url: String, input: StableFLT, completion: @escaping (Int, String, StableFLT) -> Void) {
        let fltInput: FineLocationTrackingInput = input.fltInput
        guard let body = encodeJson(fltInput),
              let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
        
        let session = fltSessions[fltSessionCount % fltSessions.count]
        fltSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func postOSR(url: String, input: OnSpotRecognitionInput, completion: @escaping (Int, String, OnSpotRecognitionInput) -> Void) {
        let osrInput: OnSpotRecognitionInput = input
        guard let body = encodeJson(osrInput),
                let request = makeRequest(url: url, body: body) else {
            DispatchQueue.main.async { completion(406, "Invalid URL or failed to encode JSON", input) }
            return
        }
            
        let session = osrSessions[osrSessionCount % osrSessions.count]
        osrSessionCount += 1
        performRequest(request: request, session: session, input: input, completion: completion)
    }
    
    func getBlackList(url: String, completion: @escaping (Int, String) -> Void) {
        var urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        
        requestURL.httpMethod = "GET"
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = JupiterNetworkConstants.TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        let dataTask = session.dataTask(with: requestURL, completionHandler: { (data, response, error) in
            
            // [error가 존재하면 종료]
            guard error == nil else {
                // [콜백 반환]
                DispatchQueue.main.async {
                    completion(500, error?.localizedDescription ?? "Fail")
                }
                return
            }
            
            // [status 코드 체크 실시]
            let successsRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
            else {
                // [콜백 반환]
                DispatchQueue.main.async {
                    completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                }
                return
            }
            
            // [response 데이터 획득]
            let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
            guard let resultLen = data else {
                completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                return
            }
            let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
            
            // [콜백 반환]
            DispatchQueue.main.async {
                completion(resultCode, resultData)
            }
        })
        
        // [network 통신 실행]
        dataTask.resume()
    }
}
