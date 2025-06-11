
import TJLabsCommon

class JupiterTrajectoryCalculator {
    private static var trajectoryBuffer = [TrajectoryInfo]()
    private static let EXTRACT_SECTION_RQ_SIZE = 7
    
    private static var pastTrajectoryInfo = [TrajectoryInfo]()
    private static var pastSearchInfo = SearchInfo()
    private static var pastMatchedDirection: Int = 0
    private static var accumulatedLengthWhenPhase2: Double = 0
    
    // Trajectory Compensation
    private static var defaultTrajCompensationArray: [Double] = [0.8, 1.0, 1.2]
    private static var trajCompensation: Double = 1.0
    private static var trajCompensationBadCount: Int = 0
    private static var isFltRequested: Bool = false
    private static var fltRequestTime: Int = 0
    
    private static var sendFailUvdIndexes = [Int]()
    private static var isNeedRemoveIndexSendFailArray: Bool = false
    private static var validIndex: Int = 0
    
    private static var isNeedTrajCheck: Bool = false
    
    static func setIsNeedTrajCheck(flag: Bool) {
        isNeedTrajCheck = flag
    }
    
    static func initTrajectoryBuffer() {
        trajectoryBuffer = [TrajectoryInfo]()
    }
    
    private static func checkTrajectoryInfo(mode: UserMode, isPhaseBreak: Bool, isBecomeForeground: Bool, isGetFirstResponse: Bool, timeForInit: Double) {
        var isNeedAllClear = false
        let trajectoryLength = mode == .MODE_VEHICLE ? JupiterMode.USER_TRAJECTORY_LENGTH_DR : JupiterMode.USER_TRAJECTORY_LENGTH_PDR
        
        if isNeedTrajCheck {
            if (isPhaseBreak) {
                let cutIdx = Int(ceil(trajectoryLength*0.5))
                let newTraj = getTrajectoryFromLast(from: trajectoryBuffer, N: cutIdx)
                if (newTraj.count > 1) {
                    for i in 1..<newTraj.count {
                        let diffX = abs(newTraj[i].jupiterResult.x - newTraj[i-1].jupiterResult.x)
                        let diffY = abs(newTraj[i].jupiterResult.y - newTraj[i-1].jupiterResult.y)
                        if (sqrt(diffX*diffX + diffY*diffY) > 3) {
                            isNeedAllClear = true
                            break
                        }
                    }
                }
                trajectoryBuffer = newTraj
            }
            isNeedTrajCheck = false
        } else if isBecomeForeground {
            JupiterStateManager.isBecomeForeground = false
            isNeedAllClear = true
        } else if isGetFirstResponse && timeForInit < JupiterTime.TIME_INIT_THRESHOLD {
            isNeedAllClear = true
        }
        
        if isNeedAllClear {
            trajectoryBuffer = [TrajectoryInfo]()
        }
    }
    
    static func updateTrajectoryBuffer(phase: Int, isDetermineSpot: Bool, mode: UserMode, uvd: UserVelocity, spotCutIndex: Int,
                                       jupiterResult : FineLocationTrackingOutput,
                                       serverResult : FineLocationTrackingOutput) -> (Bool, [TrajectoryInfo]) {
        let trajectoryInfo = TrajectoryInfo(uvd: uvd, jupiterResult: jupiterResult, serverResult: serverResult)
        checkTrajectoryInfo(mode: mode, isPhaseBreak: JupiterStateManager.isPhaseBreak, isBecomeForeground: JupiterStateManager.isBecomeForeground, isGetFirstResponse: JupiterStateManager.isGetFirstResponse, timeForInit: JupiterTime.TIME_INIT)
        var trajectoryBufferCopy = trajectoryBuffer
        trajectoryBufferCopy.append(trajectoryInfo)
        
        let cumulatedLengthThreshold: Double = mode == .MODE_PEDESTRIAN ? JupiterMode.USER_TRAJECTORY_LENGTH_PDR : JupiterMode.USER_TRAJECTORY_LENGTH_DR
        
        var isNeedAllClear: Bool = false
        if mode == .MODE_PEDESTRIAN {
            let controlPdrResult = controlPdrTrajectoryInfo()
            isNeedAllClear = controlPdrResult.0
            trajectoryBufferCopy = controlPdrResult.1
        } else {
            let controlDrResult = controlDrTrajectoryInfo(phase: phase, trajectoryBufferInput: trajectoryBufferCopy, isDetermineSpot: isDetermineSpot, spotCutIndex: spotCutIndex, lengthCondition: cumulatedLengthThreshold)
            isNeedAllClear = controlDrResult.0
            trajectoryBufferCopy = controlDrResult.1
        }
        
        trajectoryBuffer = trajectoryBufferCopy
        return (isNeedAllClear, trajectoryBufferCopy)
    }
    
    private static func controlPdrTrajectoryInfo() -> (Bool, [TrajectoryInfo]) {
        return (false, [])
    }
    
    private static func controlDrTrajectoryInfo(phase: Int, trajectoryBufferInput: [TrajectoryInfo],
                                                isDetermineSpot: Bool, spotCutIndex: Int, lengthCondition: Double) -> (Bool, [TrajectoryInfo]) {
        var trajectoryBufferForDr = trajectoryBufferInput
        var isNeedAllClear = false
        
        if phase != JupiterPhase.PHASE_2 {
            if isDetermineSpot {
                let newTraj = getTrajectoryFromLast(from: trajectoryBufferForDr, N: spotCutIndex)
                accumulatedLengthWhenPhase2 = calculateTrajectoryLength(trajectoryBuffer: newTraj)
                JupiterBuildingLevelChanger.isDetermineSpot = false
                JupiterBuildingLevelChanger.updatePositionInDRArea = [Double]()
            } else {
                var trajLength = calculateTrajectoryLength(trajectoryBuffer: trajectoryBufferForDr)
                
                if trajLength > lengthCondition {
                    trajectoryBufferForDr.remove(at: 0)
                }
            }
            
            if !trajectoryBufferForDr.isEmpty {
                let isTailIndexSendFail = checkIsTailIndexSendFail(trajectoryInfo: trajectoryBufferForDr, sendFailUvdIndexes: sendFailUvdIndexes)
                if (isTailIndexSendFail) {
                    let validTrajectoryInfoResult = getValidTrajectory(trajectoryInfo: trajectoryBufferForDr, sendFailUvdIndexes: sendFailUvdIndexes, mode: .MODE_VEHICLE)
                    if (!validTrajectoryInfoResult.0.isEmpty) {
                        let trajLength = calculateTrajectoryLength(trajectoryBuffer: validTrajectoryInfoResult.0)
                        if (trajLength > 10) {
                            trajectoryBufferForDr = validTrajectoryInfoResult.0
                            validIndex = validTrajectoryInfoResult.1
                            isNeedRemoveIndexSendFailArray = true
                        } else {
                            // Phase 깨줘야한다
                            isNeedAllClear = true
                        }
                    } else {
                        // Phase 깨줘야한다
                        isNeedAllClear = true
                    }
                }
            }
        }
        
        if isNeedAllClear {
            trajectoryBufferForDr = [TrajectoryInfo]()
        }
        
        return (isNeedAllClear, trajectoryBufferForDr)
    }
    
    static func setPastInfo(trajInfo: [TrajectoryInfo], searchInfo: SearchInfo, matchedDirection: Int) {
        pastTrajectoryInfo = trajInfo
        pastSearchInfo = searchInfo
        pastMatchedDirection = matchedDirection
    }
    
    static func makePdrSearchInfo(phase: Int, trajectoryBuffer: [TrajectoryInfo], lengthThreshold: Double) -> SearchInfo {
        let reqLengthForMajorHeading = lengthThreshold <= 20 ? (lengthThreshold - 5) / 2 : JupiterMode.REQUIRED_LENGTH_FOR_MAJOR_HEADING

        var searchInfo = SearchInfo()
        if trajectoryBuffer.isEmpty { return searchInfo }
        
        let lastIndex = trajectoryBuffer.count-1
        var userX = trajectoryBuffer[lastIndex].jupiterResult.x
        var userY = trajectoryBuffer[lastIndex].jupiterResult.y
        let serverX = trajectoryBuffer[lastIndex].serverResult.x
        let serverY = trajectoryBuffer[lastIndex].serverResult.y

        let buildingName = trajectoryBuffer[lastIndex].serverResult.building_name
        let levelName = trajectoryBuffer[lastIndex].serverResult.level_name

        var uvdRawHeading = [Double]()
        var uvdHeading = [Double]()
        for value in trajectoryBuffer {
            uvdRawHeading.append(value.uvd.heading)
            uvdHeading.append(TJLabsUtilFunctions.shared.compensateDegree(value.uvd.heading))
        }
        
        if (phase < JupiterPhase.PHASE_4) {
            let paddingValue = JupiterMode.USER_TRAJECTORY_LENGTH_PDR * 0.8
            let trajLength = calculateTrajectoryLength(trajectoryBuffer: trajectoryBuffer)

            if (phase == JupiterPhase.PHASE_1) {
                userX = serverX
                userY = serverY
            }

            var searchRange = [userX - paddingValue, userY - paddingValue, userX + paddingValue, userY + paddingValue]
            var searchHeadings = [Double]()
            if (trajLength > reqLengthForMajorHeading) {
                let ppHeadings = JupiterPathMatchingCalculator.shared.getPathMatchingHeadings(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: buildingName, level: levelName, x: userX, y: userY, paddingValue: paddingValue, mode: .MODE_PEDESTRIAN)
                let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: EXTRACT_SECTION_RQ_SIZE)
                if !headingLeastChangeSection.isEmpty {
                    let headingForCompensation = headingLeastChangeSection.average - uvdRawHeading[0]
                    for ppHeading in ppHeadings {
                        let tailHeading = TJLabsUtilFunctions.shared.compensateDegree(ppHeading - headingForCompensation)
                        searchHeadings.append(tailHeading)
                    }
                }
            }

            searchInfo.tailIndex = trajectoryBuffer[0].uvd.index
            searchInfo.searchRange = searchRange.map { Int($0) }
            if !searchHeadings.isEmpty {
                searchInfo.searchDirection = searchHeadings.map { Int($0) }
            }
        } else {
            //TODO() phase 4 이상인 경우
        }
        return searchInfo
    }
    
    static func makeDrSearchInfo(phase: Int, isPhaseBreak: Bool, trajectoryBuffer: [TrajectoryInfo]) -> SearchInfo {
        var searchInfo = SearchInfo()
        if (trajectoryBuffer.isEmpty) { return searchInfo }

        var userX = trajectoryBuffer[trajectoryBuffer.count-1].jupiterResult.x
        var userY = trajectoryBuffer[trajectoryBuffer.count-1].jupiterResult.y

        let serverX = trajectoryBuffer[trajectoryBuffer.count-1].serverResult.x
        let serverY = trajectoryBuffer[trajectoryBuffer.count-1].serverResult.y

        let buildingName = trajectoryBuffer[trajectoryBuffer.count-1].serverResult.building_name
        let levelName = trajectoryBuffer[trajectoryBuffer.count-1].serverResult.level_name

        var uvdRawHeading = [Double]()
        var uvdHeading = [Double]()
        
        for value in trajectoryBuffer {
            uvdRawHeading.append(value.uvd.heading)
            uvdHeading.append(TJLabsUtilFunctions.shared.compensateDegree(value.uvd.heading))
        }
        
        if (phase != JupiterPhase.PHASE_2 && phase < JupiterPhase.PHASE_4) {
            searchInfo.tailIndex = trajectoryBuffer[0].uvd.index
            
            let paddingValue = JupiterMode.USER_TRAJECTORY_LENGTH_DR*1.2
            let trajLength = calculateTrajectoryLength(trajectoryBuffer: trajectoryBuffer)
            
            if (isPhaseBreak) {
                userX = serverX
                userY = serverY
            }
            
            let searchRange: [Double] = [userX - paddingValue, userY - paddingValue, userX + paddingValue, userY + paddingValue]
            searchInfo.searchRange = searchRange.map { Int($0) }
        
            let ppHeadings = JupiterPathMatchingCalculator.shared.getPathMatchingHeadings(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: buildingName, level: levelName, x: userX, y: userY, paddingValue: paddingValue, mode: .MODE_VEHICLE)
            var searchHeadings: [Double] = []
            if (trajLength <= 30) {
                searchHeadings = ppHeadings
            } else {
                let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
                if (headingLeastChangeSection.isEmpty) {
                    let diffHeadingHeadTail = abs(uvdRawHeading[uvdRawHeading.count-1] - uvdRawHeading[0])
                    if (diffHeadingHeadTail < 5) {
                        for ppHeading in ppHeadings {
                            let defaultHeading = ppHeading - diffHeadingHeadTail
                            searchHeadings.append(TJLabsUtilFunctions.shared.compensateDegree(defaultHeading))
                        }
                    } else {
                        for ppHeading in ppHeadings {
                            let defaultHeading = ppHeading - diffHeadingHeadTail
                            searchHeadings.append(TJLabsUtilFunctions.shared.compensateDegree(defaultHeading))
                        }
                    }
                } else {
                    let headingForCompensation = headingLeastChangeSection.average - uvdRawHeading[0]
                    for ppHeading in ppHeadings {
                        searchHeadings.append(TJLabsUtilFunctions.shared.compensateDegree(ppHeading - headingForCompensation))
                    }
                }
            }
            
            let uniqueSearchHeadings = Array(Set(searchHeadings))
            searchInfo.searchDirection = uniqueSearchHeadings.map { Int($0) }
        }
        
        return searchInfo
    }
    
    static func extractSectionWithLeastChange(inputArray: [Double], requiredSize: Int) -> [Double] {
        var resultArray = [Double]()
        guard inputArray.count > requiredSize else {
            return []
        }
        
        var compensatedArray = [Double] (repeating: 0, count: inputArray.count)
        for i in 0..<inputArray.count {
            compensatedArray[i] = TJLabsUtilFunctions.shared.compensateDegree(inputArray[i])
        }
        
        var bestSliceStartIndex = 0
        var bestSliceEndIndex = 0

        for startIndex in 0..<(inputArray.count-(requiredSize-1)) {
            for endIndex in (startIndex+requiredSize)..<inputArray.count {
                let slice = Array(compensatedArray[startIndex...endIndex])
                let circularStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: slice)
                if circularStd < 5 && slice.count > bestSliceEndIndex - bestSliceStartIndex {
                    bestSliceStartIndex = startIndex
                    bestSliceEndIndex = endIndex
                }
            }
        }
        
        resultArray = Array(inputArray[bestSliceStartIndex...bestSliceEndIndex])
        if resultArray.count > requiredSize {
            return resultArray
        } else {
            return []
        }
    }
    
    static func calculateTrajectoryLength(trajectoryBuffer: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in trajectoryBuffer {
            trajLength += unitTraj.uvd.length
        }
        let roundedTrajLength = (trajLength * 1e4).rounded() / 1e4
        return roundedTrajLength
    }
    
    static func calculateAccumulatedDiagonal(trajectoryBuffer: [TrajectoryInfo]) -> Double {
        var trajDiagonal = 0.0
        if (!trajectoryBuffer.isEmpty) {
            let trajectoryFromHead = calcTrajectoryFromHead(trajectoryBuffer: trajectoryBuffer)
            let trajectoryMinMax = getMinMaxValues(for: trajectoryFromHead)
            let dx = trajectoryMinMax[2] - trajectoryMinMax[0]
            let dy = trajectoryMinMax[3] - trajectoryMinMax[1]
            trajDiagonal = sqrt(dx*dx + dy*dy)
        }
        return trajDiagonal
    }
    
    static func calcTrajectoryFromHead(trajectoryBuffer: [TrajectoryInfo]) -> [[Double]] {
        var trajectoryFromHead = [[Double]]()
        if trajectoryBuffer.isEmpty {
            return trajectoryFromHead
        } else {
            let startHeading = trajectoryBuffer[0].uvd.heading
            guard let headInfo = trajectoryBuffer.last else { return trajectoryFromHead }
            var xyFromHead: [Double] = [headInfo.jupiterResult.x, headInfo.jupiterResult.y]
            var headingFromHead = [Double] (repeating: 0, count: trajectoryBuffer.count)
            for i in 0..<trajectoryBuffer.count {
                headingFromHead[i] = TJLabsUtilFunctions.shared.compensateDegree(trajectoryBuffer[i].uvd.heading  - 180 - startHeading)
            }
            var trajectoryFromHead = [[Double]]()
            trajectoryFromHead.append(xyFromHead)
            for i in (1..<trajectoryBuffer.count).reversed() {
                let headAngle = TJLabsUtilFunctions.shared.degree2radian(degree: headingFromHead[i])
                xyFromHead[0] = xyFromHead[0] + trajectoryBuffer[i].uvd.length*cos(headAngle)
                xyFromHead[1] = xyFromHead[1] + trajectoryBuffer[i].uvd.length*sin(headAngle)
                trajectoryFromHead.append(xyFromHead)
            }
            return trajectoryFromHead
        }
    }
    
    static func getMinMaxValues(for array: [[Double]]) -> [Double] {
        guard !array.isEmpty else {
            return []
        }
        
        var xMin = array[0][0]
        var yMin = array[0][1]
        var xMax = array[0][0]
        var yMax = array[0][1]
        
        for row in array {
            xMin = min(xMin, row[0])
            yMin = min(yMin, row[1])
            xMax = max(xMax, row[0])
            yMax = max(yMax, row[1])
        }
        
        return [xMin, yMin, xMax, yMax]
    }
    
    static func propagateUsingUvd(unitDRInfoBuffer: [UserVelocity], fltResult: FineLocationTrackingOutput) -> (Bool, xyhs) {
        var isSuccess: Bool = false
        var propagationValues = xyhs()
        let resultIndex = fltResult.index
        var matchedIndex: Int = -1
        
        for i in 0..<unitDRInfoBuffer.count {
            let drBufferIndex = unitDRInfoBuffer[i].index
            if (drBufferIndex == resultIndex) {
                matchedIndex = i
            }
        }
        
        var dx: Double = 0
        var dy: Double = 0
        var dh: Double = 0
        
        if (matchedIndex != -1) {
            let drBuffrerFromIndex = TJLabsUtilFunctions.shared.sliceArrayFrom(unitDRInfoBuffer, startingFrom: matchedIndex)
            let headingCompensation: Double = fltResult.absolute_heading - drBuffrerFromIndex[0].heading
            var headingBuffer = [Double]()
            for i in 0..<drBuffrerFromIndex.count {
                let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(drBuffrerFromIndex[i].heading + headingCompensation)
                let headAngle = TJLabsUtilFunctions.shared.degree2radian(degree: compensatedHeading)
                headingBuffer.append(compensatedHeading)
                
                dx += drBuffrerFromIndex[i].length * cos(headAngle)
                dy += drBuffrerFromIndex[i].length * sin(headAngle)
            }
            dh = headingBuffer[headingBuffer.count-1] - headingBuffer[0]
            
            isSuccess = true
            propagationValues = xyhs(x: dx, y: dy, heading: dh, scale: 1.0)
        }
        
        return (isSuccess, propagationValues)
    }
    
    static func checkHasMajorDirection(trajectoryBuffer: [TrajectoryInfo]) -> Bool {
        var uvdRawHeading = [Double]()
        for value in trajectoryBuffer {
            uvdRawHeading.append(value.uvd.heading)
        }
        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
        return headingLeastChangeSection.isEmpty ? false : true
    }
    
    static func updateTrajCompensationArray(result: FineLocationTrackingOutput) {
        if (self.isFltRequested) {
            let compensationCheckTime = abs(result.mobile_time - self.fltRequestTime)
            if (compensationCheckTime < 100) {
                if (result.scc < 0.55) {
                    self.trajCompensationBadCount += 1
                } else {
                    if (result.scc > 0.6) {
                        let digit: Double = pow(10, 4)
                        self.trajCompensation = round((result.sc_compensation*digit)/digit)
                    }
                    self.trajCompensationBadCount = 0
                }
                if (self.trajCompensationBadCount > 1) {
                    self.trajCompensationBadCount = 0
                    self.isFltRequested = false
                }
            } else if (compensationCheckTime > 3000) {
                self.isFltRequested = false
            }
        }
    }
    
    static func getValidTrajectory(trajectoryInfo: [TrajectoryInfo], sendFailUvdIndexes: [Int], mode: UserMode) -> ([TrajectoryInfo], Int) {
        var result = [TrajectoryInfo]()
        var isFindValidIndex: Bool = false
        var validIndex: Int = 0
        var validUvdIndex: Int = trajectoryInfo[0].uvd.index
        
        for i in 0..<trajectoryInfo.count{
            let uvdIndex = trajectoryInfo[i].uvd.index
            let uvdLookingFlag = mode == .MODE_VEHICLE ? true : trajectoryInfo[i].uvd.looking

            if !sendFailUvdIndexes.contains(uvdIndex) && uvdLookingFlag {
                isFindValidIndex = true
                validIndex = i
                validUvdIndex = uvdIndex
                break
            }
        }
        if (isFindValidIndex) {
            for i in validIndex..<trajectoryInfo.count {
                result.append(trajectoryInfo[i])
            }
        }
        return (result, validUvdIndex)
    }
    
    static func getTrajCompensationArray(mode: UserMode, currentTime: Int, trajLength: Double) -> [Double] {
        var trajCompensationArray: [Double] = [trajCompensation]
        let lengthCondition = mode == .MODE_VEHICLE ? JupiterMode.USER_TRAJECTORY_LENGTH_DR : JupiterMode.USER_TRAJECTORY_LENGTH_PDR
        if (trajLength < lengthCondition) {
            trajCompensationArray = [1.01]
        } else {
            if (isFltRequested) {
                trajCompensationArray = [1.01]
            } else {
                trajCompensationArray = defaultTrajCompensationArray
                fltRequestTime = currentTime
                isFltRequested = true
            }
        }
        return trajCompensationArray
    }
    
    static func getTrajectoryFromLast(from trajectoryInfo: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        let size = trajectoryInfo.count
        guard size >= N else {
            return trajectoryInfo
        }
        
        let startIndex = size - N
        let endIndex = size
        
        var result: [TrajectoryInfo] = []
        for i in startIndex..<endIndex {
            result.append(trajectoryInfo[i])
        }

        return result
    }
    
    private static func checkIsTailIndexSendFail(trajectoryInfo: [TrajectoryInfo], sendFailUvdIndexes: [Int]) -> Bool {
        var isTailIndexSendFail: Bool = false
        let tailIndex = trajectoryInfo[0].uvd.index
        if sendFailUvdIndexes.contains(tailIndex) {
            isTailIndexSendFail = true
        }
        return isTailIndexSendFail
    }
    
    static func stackPostUvdFailData(inputUvd: [UserVelocity]) {
        if (isNeedRemoveIndexSendFailArray) {
            var updatedArray = [Int]()
            for i in 0..<self.sendFailUvdIndexes.count {
                if sendFailUvdIndexes[i] > validIndex {
                    updatedArray.append(sendFailUvdIndexes[i])
                }
            }
            sendFailUvdIndexes = updatedArray
            isNeedRemoveIndexSendFailArray = false
        }
        
        for i in 0..<inputUvd.count {
            sendFailUvdIndexes.append(inputUvd[i].index)
        }
    }
}
