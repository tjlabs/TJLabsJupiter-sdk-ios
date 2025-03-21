
class JupiterCalculator {
    static func calculatePhase1(input: FineLocationTrackingInput, completion: @escaping (JupiterCalculatorResults) -> Void) {
        
        let postInput = FLT(fltInput: input, trajInfoList: [], searchInfo: SearchInfo())
        JupiterNetworkManager.shared.postFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: postInput, completion: { statusCode, returnedString, input in
            var output = JupiterCalculatorResults(fltResultList: [], fltInput: postInput.fltInput, inputTrajectoryInfo: postInput.trajInfoList, inputSearchInfo: postInput.searchInfo)
            if statusCode == 200 {
                let decoded = decodeFineLocationTrackingOutputList(jsonString: returnedString)
                if decoded.0 {
                    output.fltResultList = decoded.1.flt_outputs
                    completion(output)
                } else {
                    
                }
            } else {
                
            }
        })
    }
    
    static func calculatePhase3(input: FineLocationTrackingInput, completion: @escaping (JupiterCalculatorResults) -> Void) {
        
    }
    
    static func calculatePhase5(input: FineLocationTrackingInput, completion: @escaping (JupiterCalculatorResults) -> Void) {
        
    }
    
    static func calculatePhase6(input: FineLocationTrackingInput, completion: @escaping (JupiterCalculatorResults) -> Void) {
        
    }
    
    // MARK: - Decode FLT output
    static func decodeFineLocationTrackingOutputList(jsonString: String) -> (Bool, FineLocationTrackingOutputList) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return (false, FineLocationTrackingOutputList(flt_outputs: []))
        }
        
        do {
            let decodedData = try JSONDecoder().decode(FineLocationTrackingOutputList.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, FineLocationTrackingOutputList(flt_outputs: []))
        }
    }
}
