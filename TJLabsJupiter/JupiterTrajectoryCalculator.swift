import Foundation
import TJLabsCommon

class JupiterTrajectoryCalculator: RFDGeneratorDelegate, UVDGeneratorDelegate {
    // MARK: - Properties
    private var currentUserTrajectoryInfo = [TrajectoryInfo]()
    private var velocity: Double = 0
    private var numBleChannels: Int = 0

    // MARK: - Initialization
    init() {}

    // MARK: - Methods
    private func updateTrajectoryInfo(uvd: UserVelocity) {
        let latestFltOutput = JupiterCalculator.getJupiterResult()
        
        if latestFltOutput.x != 0 && latestFltOutput.y != 0 {
            var tempUnitTrajectoryInfo = TrajectoryInfo()
            tempUnitTrajectoryInfo.index = uvd.index
            tempUnitTrajectoryInfo.length = uvd.length
            tempUnitTrajectoryInfo.heading = uvd.heading
            tempUnitTrajectoryInfo.lookingFlag = uvd.looking
            tempUnitTrajectoryInfo.numBleChannels = self.numBleChannels
            tempUnitTrajectoryInfo.scc = latestFltOutput.scc
            tempUnitTrajectoryInfo.userBuilding = latestFltOutput.building_name
            tempUnitTrajectoryInfo.userLevel = latestFltOutput.level_name
            tempUnitTrajectoryInfo.userX = latestFltOutput.x
            tempUnitTrajectoryInfo.userY = latestFltOutput.y
            tempUnitTrajectoryInfo.userHeading = latestFltOutput.absolute_heading
            
            self.currentUserTrajectoryInfo.append(tempUnitTrajectoryInfo)
            self.currentUserTrajectoryInfo = self.updateTrajectoryInfoWithLength(trajectoryInfo: self.currentUserTrajectoryInfo, LENGTH_CONDITION: JupiterMode.USER_TRAJECTORY_LENGTH_PDR)
        }
    }
    
    private func updateTrajectoryInfoWithLength(trajectoryInfo: [TrajectoryInfo], LENGTH_CONDITION: Double) -> [TrajectoryInfo] {
        guard !trajectoryInfo.isEmpty else { return trajectoryInfo }
        
        let startHeading = trajectoryInfo[0].heading
        let headInfo = trajectoryInfo.last!
        var accumulatedLength: Double = 0
        var longTrajIndex = 0
        var shortTrajIndex = 0
        var isFindLong = false
        var isFindShort = false
        
        var xyFromHead = [headInfo.userX, headInfo.userY]
        let headingFromHead = trajectoryInfo.map {
            TJLabsUtilFunctions.shared.compensateDegree($0.heading - 180 - startHeading)
        }
        
        var trajectoryFromHead = [xyFromHead]
        
        for i in stride(from: trajectoryInfo.count - 1, through: 0, by: -1) {
            let headAngle = headingFromHead[i]
            let uvdLength = trajectoryInfo[i].length
            accumulatedLength += uvdLength

            if accumulatedLength >= LENGTH_CONDITION * 2, !isFindLong {
                isFindLong = true
                longTrajIndex = i
            }

            if accumulatedLength >= LENGTH_CONDITION, !isFindShort {
                isFindShort = true
                shortTrajIndex = i
            }

            xyFromHead[0] += uvdLength * cos(TJLabsUtilFunctions.shared.degree2radian(degree: headAngle))
            xyFromHead[1] += uvdLength * sin(TJLabsUtilFunctions.shared.degree2radian(degree: headAngle))
            trajectoryFromHead.append(xyFromHead)
        }
        
        let trajectoryMinMax = getMinMaxValues(for: trajectoryFromHead)
        let width = trajectoryMinMax[2] - trajectoryMinMax[0]
        let height = trajectoryMinMax[3] - trajectoryMinMax[1]
        
        let indexToUse = (width <= 3 || height <= 3) ? longTrajIndex : shortTrajIndex
        return getTrajectoryFromN(trajectoryInfo: trajectoryInfo, N: indexToUse)
    }
    
    private func makeSearchInfoInPhase3() {
        let trajectoryInfo = self.currentUserTrajectoryInfo

        let paddingValue = JupiterMode.USER_TRAJECTORY_LENGTH_PDR * 0.8
        var userX = trajectoryInfo.last!.userX
        var userY = trajectoryInfo.last!.userY
        
        let uvdRawHeading = trajectoryInfo.map { $0.heading }
        let uvdHeading = uvdRawHeading.map { TJLabsUtilFunctions.shared.compensateDegree($0) }
        
        let phaseBreakResult = JupiterCalculator.phaseBreakFineLocationTrackingResult
        if JupiterCalculator.getPhaseBreak(),
           !phaseBreakResult.building_name.isEmpty,
           !phaseBreakResult.level_name.isEmpty {
            userX = phaseBreakResult.x
            userY = phaseBreakResult.y
        }
        
        let searchRange = [
            userX - paddingValue,
            userY - paddingValue,
            userX + paddingValue,
            userY + paddingValue
        ]
        
        JupiterCalculator.searchRange = searchRange.map { Int($0) }
        JupiterCalculator.searchDirectionList = uvdHeading.map { Int($0) }
        JupiterCalculator.tailIndex = trajectoryInfo.first!.index
    }

    
    private func getTrajectoryFromN(trajectoryInfo: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        return Array(trajectoryInfo.suffix(from: min(N, trajectoryInfo.count)))
    }
    
    private func getMinMaxValues(for array2D: [[Double]]) -> [Double] {
        guard let firstRow = array2D.first else { return [] }
        var xMin = firstRow[0], yMin = firstRow[1]
        var xMax = firstRow[0], yMax = firstRow[1]
        
        for row in array2D {
            xMin = min(xMin, row[0])
            yMin = min(yMin, row[1])
            xMax = max(xMax, row[0])
            yMax = max(yMax, row[1])
        }
        
        return [xMin, yMin, xMax, yMax]
    }
    
    private func makeSearchInfo(phase: Int) {
        if phase == 0 {
            
        } else if phase == 2 {
            
        } else if phase == 3 {
            self.makeSearchInfoInPhase3()
        } else if phase == 5 {
            
        } else if phase == 6 {
            
        }
    }
    
    private func calculateTrajectoryLength(trajectoryInfo: [TrajectoryInfo]) -> Double {
        let totalLength = trajectoryInfo.reduce(0.0) { $0 + $1.length }
        return (totalLength * 1e4).rounded() / 1e4
    }
    
    func extractSectionWithLeastChange(inputArray: [Double], requiredSize: Int) -> [Double] {
        guard inputArray.count > requiredSize else { return [] }
        let compensatedArray = inputArray.map { TJLabsUtilFunctions.shared.compensateDegree($0) }
        var bestSliceRange: Range<Int>?
        for startIndex in 0...(compensatedArray.count - requiredSize) {
            for endIndex in (startIndex + requiredSize - 1)..<compensatedArray.count {
                let slice = Array(compensatedArray[startIndex...endIndex])
                let circularStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: slice)
                if circularStd < 5, bestSliceRange == nil || slice.count > bestSliceRange!.count {
                    bestSliceRange = startIndex..<(endIndex + 1)
                }
            }
        }
        
        guard let range = bestSliceRange else { return [] }
        let result = TJLabsUtilFunctions.shared.sliceArrayFromTo(inputArray, startingFrom: range.lowerBound, endTo: range.upperBound)
        return result.count > requiredSize ? result : []
    }
    

    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        self.numBleChannels = RFDFunctions.shared.getBleChannelNum(bleAvg: receivedForce.ble)
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        // TODO: Handle RFD Error
    }
    
    // MARK: - UVDGeneratorDelegate Methods
    func onPressureResult(_ generator: UVDGenerator, hPa: Double) {
        // TODO: Handle pressure result
    }

    func onUvdError(_ generator: UVDGenerator, error: String) {
        // TODO: Handle UVD error
    }

    func onUvdPauseMillis(_ generator: UVDGenerator, time: Double) {
        // TODO: Handle UVD pause
    }

    func onUvdResult(_ generator: UVDGenerator, mode: UserMode, userVelocity: UserVelocity) {
        self.updateTrajectoryInfo(uvd: userVelocity)
        self.makeSearchInfo(phase: JupiterCalculator.phase)
    }

    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        self.velocity = kmPh
    }
}
