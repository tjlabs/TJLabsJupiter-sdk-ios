
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
    
    static func calculatePhase3(input: FineLocationTrackingInput, trajectoryBuffer: [TrajectoryInfo], searchInfo: SearchInfo, completion: @escaping (JupiterCalculatorResults) -> Void) {
        let postInput = FLT(fltInput: input, trajInfoList: trajectoryBuffer, searchInfo: searchInfo)
        print("(CheckJupiter) Phase3 Input : fltInput = \(postInput.fltInput) // searchInfo = \(searchInfo)")
        JupiterNetworkManager.shared.postFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: postInput, completion: { statusCode, returnedString, input in
            print("(CheckJupiter) Phase3 Output : \(statusCode) // \(returnedString)")
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
    
    static func calculatePhase5(input: FineLocationTrackingInput, completion: @escaping (JupiterStableCalculatorResults) -> Void) {
        
    }
    
    static func calculatePhase6(input: FineLocationTrackingInput, trajectoryBuffer: [TrajectoryInfo], nodeCandidateInfo: NodeCandidateInfo, completion: @escaping (JupiterStableCalculatorResults) -> Void) {
        let postInput = StableFLT(fltInput: input, trajInfoList: trajectoryBuffer, nodeCandidateInfo: nodeCandidateInfo)
        
        JupiterNetworkManager.shared.postStableFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: postInput, completion: { statusCode, returnedString, input in
            print("(CheckJupiter) Phase6 Stable Output : \(statusCode) // \(returnedString)")
            var output = JupiterStableCalculatorResults(fltResultList: [], fltInput: postInput.fltInput, inputTrajectoryInfo: postInput.trajInfoList, nodeCandidateInfo: postInput.nodeCandidateInfo)
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
