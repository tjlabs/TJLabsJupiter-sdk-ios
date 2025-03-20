
class JupiterResultSelector {
    static let RESULT_SELECT_RATIO = 0.85
    
    static func selectResult(results: [FineLocationTrackingOutput], nodeCandidatesInfo: NodeCandidateInfo) -> (Bool, FineLocationTrackingOutput) {
        let fltOutputs = results
        if fltOutputs.count == 1 {
            return (true, fltOutputs[0])
        } else if (fltOutputs.count > 1) {
            let sortedFltOutputs = fltOutputs.sorted(by: { $0.scc > $1.scc })
            let firstFltOutput = sortedFltOutputs[0]
            let secondFltOutput = sortedFltOutputs[1]

            if firstFltOutput.scc != 0 {
                let ratio = secondFltOutput.scc / firstFltOutput.scc
                if ratio < RESULT_SELECT_RATIO {
                    return (true, firstFltOutput)
                } else {
                    if nodeCandidatesInfo.nodeCandidatesInfo.isEmpty {
                        return (false, FineLocationTrackingOutput())
                    } else {
                        return (false, firstFltOutput)
//                        print(getLocalTimeString() + " , (Olympus) selectResult (Ambiguous) : index = \(firstFltOutput.index) // 1st = \(firstFltOutput.scc) // 2nd = \(secondFltOutput.scc) // ratio = \(ratio)")
//                        let inputNodeNumber = nodeCandidatesInfo.nodeCandidatesInfo[0].nodeNumber
//                        for output in fltOutputs {
//                            if inputNodeNumber == output.node_number {
////                                print(getLocalTimeString() + " , (Olympus) selectResult (Ambiguous & Select) : index = \(firstFltOutput.index) // output = \(output)")
//                                return (false, output)
//                            }
//                        }
//                        return (false, FineLocationTrackingFromServer())
                    }
                }
            } else {
                return (false, FineLocationTrackingOutput())
            }
        } else {
            return (false, FineLocationTrackingOutput())
        }
    }


    static func selectBestResult(results: [FineLocationTrackingOutput]) -> FineLocationTrackingOutput {
        let fltOutputs = results
        var highestSCC: Double = 0
        let sccArray: [Double] = fltOutputs.map { $0.scc }
        
        var resultToReturn: FineLocationTrackingOutput = fltOutputs[0]
        for result in fltOutputs {
            if result.scc > highestSCC {
                resultToReturn = result
                highestSCC = result.scc
            }
        }
        return resultToReturn
    }
}
