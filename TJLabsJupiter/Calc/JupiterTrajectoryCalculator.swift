
import TJLabsCommon

class JupiterTrajectoryCalculator {
    init() { }
    
    private var trajectoryBuffer = [TrajectoryInfo]()
    private let EXTRACT_SECTION_RQ_SIZE = 7
    
    func updateTrajectoryBuffer(mode: UserMode, uvd: UserVelocity, jupiterResult: JupiterResult, serverResult: FineLocationTrackingOutput) -> [TrajectoryInfo] {
        let trajectoryInfo = TrajectoryInfo(uvd: uvd, jupiterResult: jupiterResult, serverResult: serverResult)
        trajectoryBuffer.append(trajectoryInfo)
        
        var cumulatedLength: Double = 0
        var cutoffIndex: Int = 0
        let cumulatedLengthThreshold: Double = mode == .MODE_PEDESTRIAN ? JupiterMode.USER_TRAJECTORY_LENGTH_PDR : JupiterMode.USER_TRAJECTORY_LENGTH_DR
        
        for i in stride(from: trajectoryBuffer.count - 1, through: 0, by: -1) {
            cumulatedLength += trajectoryBuffer[i].uvd.length
            if cumulatedLength > cumulatedLengthThreshold {
                cutoffIndex = i
                break
            }
        }

        if cutoffIndex < trajectoryBuffer.count {
            trajectoryBuffer = Array(trajectoryBuffer[cutoffIndex..<trajectoryBuffer.count])
        }

        return trajectoryBuffer
    }
    
    func extractSectionWithLeastChange(inputArray: [Double], requiredSize: Int) -> [Double] {
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
    
    func calculateTrajectoryLength(trajectoryInfo: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in trajectoryInfo {
            trajLength += unitTraj.uvd.length
        }
        let roundedTrajLength = (trajLength * 1e4).rounded() / 1e4
        return roundedTrajLength
    }
    
    func calculateAccumulatedDiagonal(trajectoryInfo: [TrajectoryInfo]) -> Double {
        var trajDiagonal = 0.0
        if (!trajectoryInfo.isEmpty) {
            let trajectoryFromHead = calcTrajectoryFromHead(trajectoryInfo: trajectoryInfo)
            let trajectoryMinMax = getMinMaxValues(for: trajectoryFromHead)
            let dx = trajectoryMinMax[2] - trajectoryMinMax[0]
            let dy = trajectoryMinMax[3] - trajectoryMinMax[1]
            trajDiagonal = sqrt(dx*dx + dy*dy)
        }
        return trajDiagonal
    }
    
    func calcTrajectoryFromHead(trajectoryInfo: [TrajectoryInfo]) -> [[Double]] {
        var trajectoryFromHead = [[Double]]()
        if trajectoryInfo.isEmpty {
            return trajectoryFromHead
        } else {
            let startHeading = trajectoryInfo[0].uvd.heading
            guard let headInfo = trajectoryInfo.last else { return trajectoryFromHead }
            var xyFromHead: [Double] = [headInfo.jupiterResult.x, headInfo.jupiterResult.y]
            var headingFromHead = [Double] (repeating: 0, count: trajectoryInfo.count)
            for i in 0..<trajectoryInfo.count {
                headingFromHead[i] = TJLabsUtilFunctions.shared.compensateDegree(trajectoryInfo[i].uvd.heading  - 180 - startHeading)
            }
            var trajectoryFromHead = [[Double]]()
            trajectoryFromHead.append(xyFromHead)
            for i in (1..<trajectoryInfo.count).reversed() {
                let headAngle = TJLabsUtilFunctions.shared.degree2radian(degree: headingFromHead[i])
                xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].uvd.length*cos(headAngle)
                xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].uvd.length*sin(headAngle)
                trajectoryFromHead.append(xyFromHead)
            }
            return trajectoryFromHead
        }
    }
    
    func getMinMaxValues(for array: [[Double]]) -> [Double] {
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
    
    func propagateUsingUvd(unitDRInfoBuffer: [UserVelocity], fltResult: FineLocationTrackingOutput) -> (Bool, xyhs) {
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
    
    func checkHasMajorDirection(trajectoryInfo: [TrajectoryInfo]) -> Bool {
        var uvdRawHeading = [Double]()
        for value in trajectoryInfo {
            uvdRawHeading.append(value.uvd.heading)
        }
        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
        return headingLeastChangeSection.isEmpty ? false : true
    }
}
