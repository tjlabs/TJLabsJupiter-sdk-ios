
import TJLabsCommon

class JupiterStackManager {
    private let DR_INFO_BUFFER_SIZE: Int = 60 // 30
    private let HEADING_BUFFER_SIZE: Int = 5

    private var unitDRInfoBuffer = [UserVelocity]()
    private var unitDRInfoBufferForPhase4 = [UserVelocity]()
    private var isNeedClearBuffer: Bool = false
    private var userMaskBuffer = [UserMask]()
    private var userUniqueMaskBuffer = [UserMask]()
    private var userMaskBufferDisplay = [UserMask]()
    private var userMaskBufferPathTrajMatching = [UserMask]()
    private var sendFailUvdIndexes = [Int]()
    private var validIndex: Int = 0
    private var isNeedRemoveIndexSendFailArray: Bool = false
    private var headingBufferForCorrection = [Double]()
    
    init() { }
    
    private func stackUnitDRInfo(unitDRInfo: UserVelocity) {
        unitDRInfoBuffer.append(unitDRInfo)
        if (unitDRInfoBuffer.count > DR_INFO_BUFFER_SIZE) {
            unitDRInfoBuffer.remove(at: 0)
        }
    }

    private func stackUnitDRInfoForPhase4(unitDRInfo: UserVelocity, isNeedClear: Bool) {
        if (isNeedClear) {
            unitDRInfoBufferForPhase4 = [UserVelocity]()
            isNeedClearBuffer = false
        }
        unitDRInfoBufferForPhase4.append(unitDRInfo)
    }

    private func stackUserMask(userMask: UserMask) {
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

    private func stackUserUniqueMask(userMask: UserMask) {
        if (userUniqueMaskBuffer.count > 0) {
            let lastUserMask = userUniqueMaskBuffer.last
            let lastIndex = lastUserMask?.index
            let lastX = lastUserMask?.x
            let lastY = lastUserMask?.y
            let currentIndex = userMask.index
            let currentX = userMask.x
            let currentY = userMask.y
            if (lastIndex == currentIndex || (lastX == currentX && lastY == currentY)) {
                userUniqueMaskBuffer.popLast()
            }
        }

        userUniqueMaskBuffer.append(userMask)
        if (userUniqueMaskBuffer.count > DR_INFO_BUFFER_SIZE) {
            userUniqueMaskBuffer.remove(at: 0)
        }
    }

    private func stackUserMaskForDisplay(data: UserMask) {
        userMaskBufferDisplay.append(data)
        if (userMaskBufferDisplay.count > 300) {
            userMaskBufferDisplay.remove(at: 0)
        }
    }

    private func stackUserMaskPathTrajMatching(data: UserMask) {
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

    func stackPostUvdFailData(inputUvd: [UserVelocity]) {
        if (isNeedRemoveIndexSendFailArray) {
            let updatedArray = sendFailUvdIndexes.filter { $0 > validIndex }
            sendFailUvdIndexes = updatedArray
            isNeedRemoveIndexSendFailArray = false
        }
        
        sendFailUvdIndexes = inputUvd.map { $0.index }
    }

    func stackHeadingForCheckCorrection(unitDRInfo: UserVelocity) {
        headingBufferForCorrection.append(unitDRInfo.heading)
        if (headingBufferForCorrection.count > HEADING_BUFFER_SIZE) {
            headingBufferForCorrection.remove(at: 0)
        }
    }
}
