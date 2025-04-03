
import TJLabsCommon

class JupiterStackManager {
    static private let DR_INFO_BUFFER_SIZE: Int = 60 // 30
    static private let HEADING_BUFFER_SIZE: Int = 5

    static var unitDRInfoBuffer = [UserVelocity]()
    static var unitDRInfoBufferForPhase4 = [UserVelocity]()
    static var isNeedClearBuffer: Bool = false
    static var userMaskBuffer = [UserMask]()
    static var userUniqueMaskBuffer = [UserMask]()
    static var userMaskBufferDisplay = [UserMask]()
    static var userMaskBufferPathTrajMatching = [UserMask]()
    static var sendFailUvdIndexes = [Int]()
    static var validIndex: Int = 0
    static var isNeedRemoveIndexSendFailArray: Bool = false
    static var headingBufferForCorrection = [Double]()
    
    static func stackUnitDRInfo(unitDRInfo: UserVelocity) {
        unitDRInfoBuffer.append(unitDRInfo)
        if (unitDRInfoBuffer.count > DR_INFO_BUFFER_SIZE) {
            unitDRInfoBuffer.remove(at: 0)
        }
    }

    static func stackUnitDRInfoForPhase4(unitDRInfo: UserVelocity, isNeedClear: Bool) {
        if (isNeedClear) {
            unitDRInfoBufferForPhase4 = [UserVelocity]()
            isNeedClearBuffer = false
        }
        unitDRInfoBufferForPhase4.append(unitDRInfo)
    }

    static func stackUserMask(userMask: UserMask) {
        if (userMaskBuffer.count > 0) {
            let lastIndex = userMaskBuffer.last?.index
            let currentIndex = userMask.index
            if (lastIndex == currentIndex) {
                _ = userMaskBuffer.popLast()
            }
        }

        userMaskBuffer.append(userMask)
        if (userMaskBuffer.count > DR_INFO_BUFFER_SIZE) {
            userMaskBuffer.remove(at: 0)
        }
    }

    static func stackUserUniqueMask(userMask: UserMask) {
        if (userUniqueMaskBuffer.count > 0) {
            let lastUserMask = userUniqueMaskBuffer.last
            let lastIndex = lastUserMask?.index
            let lastX = lastUserMask?.x
            let lastY = lastUserMask?.y
            let currentIndex = userMask.index
            let currentX = userMask.x
            let currentY = userMask.y
            if (lastIndex == currentIndex || (lastX == currentX && lastY == currentY)) {
                _ = userUniqueMaskBuffer.popLast()
            }
        }

        userUniqueMaskBuffer.append(userMask)
        if (userUniqueMaskBuffer.count > DR_INFO_BUFFER_SIZE) {
            userUniqueMaskBuffer.remove(at: 0)
        }
    }

    static func stackUserMaskForDisplay(data: UserMask) {
        userMaskBufferDisplay.append(data)
        if (userMaskBufferDisplay.count > 300) {
            userMaskBufferDisplay.remove(at: 0)
        }
    }

    static func stackUserMaskPathTrajMatching(data: UserMask) {
        if (userMaskBufferPathTrajMatching.count > 0) {
            let lastIndex = userMaskBufferPathTrajMatching.last?.index
            let currentIndex = data.index
            if (lastIndex == currentIndex) {
                _ = userMaskBufferPathTrajMatching.popLast()
            }
        }
        
        userMaskBufferPathTrajMatching.append(data)
        if (userMaskBufferPathTrajMatching.count > DR_INFO_BUFFER_SIZE) {
            userMaskBufferPathTrajMatching.remove(at: 0)
        }
    }

    static func stackPostUvdFailData(inputUvd: [UserVelocity]) {
        if (isNeedRemoveIndexSendFailArray) {
            let updatedArray = sendFailUvdIndexes.filter { $0 > validIndex }
            sendFailUvdIndexes = updatedArray
            isNeedRemoveIndexSendFailArray = false
        }
        
        sendFailUvdIndexes = inputUvd.map { $0.index }
    }

    static func stackHeadingForCheckCorrection(unitDRInfo: UserVelocity) {
        headingBufferForCorrection.append(unitDRInfo.heading)
        if (headingBufferForCorrection.count > HEADING_BUFFER_SIZE) {
            headingBufferForCorrection.remove(at: 0)
        }
    }
    
    static func isDrBufferStraightCircularStd(uvdBuffer: [UserVelocity], numIndex: Int, condition: Double = 1) -> (Bool, Double) {
        if (uvdBuffer.count >= numIndex) {
            let firstIndex = uvdBuffer.count-numIndex
            var headingBuffer = [Double]()
            for i in firstIndex..<uvdBuffer.count-1 {
                let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(uvdBuffer[i].heading)
                headingBuffer.append(compensatedHeading)
            }
            let headingStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: headingBuffer)
            return (headingStd <= condition) ? (true, headingStd) : (false, headingStd)
        } else {
            return (false, 360)
        }
    }
}
