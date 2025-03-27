
import TJLabsCommon
import TJLabsResource

class JupiterRouteTracker {
    static let shared = JupiterRouteTracker()
    init () { }
    
    private var entranceRoute = [String: EntranceRouteData]()
    private var entranceVelocityScales = [String: Double]()
    private var entranceOuterMostWardId = [String: String]()
    private var entranceInnerWardID = [String: String]()
    private var entranceInnerWardRSSI = [String: Double]()
    private var entranceInnerWardCoord = [String: xyhs]()

    private var currentEntranceKey: String = ""
    private var checkStartRouteTrackFlag: Bool = false
    private var checkStartRouteTrackTimeStamp: Double = 0
    private var scaledDistance: Double = 0

    private var isLastEntrancePosition: Bool = false
    private var checkForcedStopRouteTrackTimeStamp: Double = 0
    
    func setEntranceRouteData(key: String, data: EntranceRouteData) {
        self.entranceRoute[key] = data
    }
    
    func setEntranceData(region: String, sectorId: String, data: EntranceData) {
        for entranceInfo in data.entranceInfoList {
            let building = entranceInfo.building
            let level = entranceInfo.level
            let entranceNumber = entranceInfo.number
            
            let key = "\(sectorId)_\(building)_\(level)_\(entranceNumber)"
            self.entranceVelocityScales[key] = entranceInfo.velocityScale
            self.entranceOuterMostWardId[key] = entranceInfo.outerWardId
            self.entranceInnerWardID[key] = entranceInfo.innerWardId
            self.entranceInnerWardRSSI[key] = entranceInfo.innerWardRssi
            self.entranceInnerWardCoord[key] = xyhs(x: entranceInfo.innerWardCoord[0], y: entranceInfo.innerWardCoord[1], heading: entranceInfo.innerWardCoord[2])
        }
    }
    
    func checkStartRouteTrack(bleAvg: [String: Double], sec: Double) -> (Bool, String) {
        var check: Bool = false
        if entranceRoute.isEmpty {
            currentEntranceKey = ""
            checkStartRouteTrackFlag = false
        }
        
        if bleAvg.isEmpty {
            currentEntranceKey = ""
            checkStartRouteTrackFlag = false
        }
        
        print("(CheckRouteTracking) : checkStartRouteTrackFlag = \(checkStartRouteTrackFlag) // bleAvg = \(bleAvg)")
        
        if !checkStartRouteTrackFlag {
            for key in bleAvg.keys {
                if entranceOuterMostWardId.values.contains(key) {
                    currentEntranceKey = entranceOuterMostWardId.first(where: { $0.value == key })?.key ?? ""
                    checkStartRouteTrackFlag = true
                    checkStartRouteTrackTimeStamp = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble()
                }
            }
        }
        print("(CheckRouteTracking) : entering entrance... // key = \(currentEntranceKey)")
        let timeDiff = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble() - checkStartRouteTrackTimeStamp
        print("(CheckRouteTracking) : timeDiff = \(timeDiff)")
        
        if (timeDiff >= sec * JupiterTime.SECONDS_TO_MILLIS && checkStartRouteTrackFlag) {
            if bleAvg.count >= 2 {
                checkStartRouteTrackFlag = false
                print("(CheckRouteTracking) : ble size = \(bleAvg.count)")
                check = true
            }
        }
        print("(CheckRouteTracking) : check = \(check)")
        
        return (check, currentEntranceKey)
    }
    
    func startRouteTracking(uvd: UserVelocity, curResult: FineLocationTrackingOutput) -> FineLocationTrackingOutput {
        var result = curResult
        
        if currentEntranceKey != "" {
            let length = uvd.length
            let scale = entranceVelocityScales[currentEntranceKey] ?? 1.0
            let scaledLength = length*scale
            scaledDistance += scaledLength
            var roundedIndex = Int(round(scaledDistance))
            print("(CheckRouteTracking) : uvd length = \(length) // scale = \(scale) // scaledLength = \(scaledLength) // scaledDistance = \(scaledDistance)")
            
            guard let routeData = self.entranceRoute[currentEntranceKey] else { return result }
            let entranceRouteLevel = routeData.routeLevel
            let entranceRouteCoord = routeData.route
            
            if roundedIndex >= entranceRouteCoord.count-1 {
                roundedIndex = entranceRouteCoord.count-1
                isLastEntrancePosition = true
            } else {
                isLastEntrancePosition = false
            }
            print("(CheckRouteTracking) : roundedIndex = \(roundedIndex)")
            
            result.level_name = entranceRouteLevel[roundedIndex]
            result.x = entranceRouteCoord[roundedIndex][0]
            result.y = entranceRouteCoord[roundedIndex][1]
            result.absolute_heading = entranceRouteCoord[roundedIndex][2]
            return result
        } else {
            return result
        }
    }
    
    func stopRouteTracking(curResult: FineLocationTrackingOutput, bleAvg: [String: Double], normalizationScale: Double, deviceMinRss: Double, standardMinRss: Double) -> (Bool, FineLocationTrackingOutput) {
        var result = curResult
        
        if let bleID = entranceInnerWardID[currentEntranceKey] {
            if let scannedRSSI = bleAvg[bleID] {
                if let thresholdRSSI = entranceInnerWardRSSI[currentEntranceKey] {
                    if let wardCoord = entranceInnerWardCoord[currentEntranceKey] {
                        let normalizedRSSI = (scannedRSSI - deviceMinRss)*normalizationScale + standardMinRss
                        result.x = wardCoord.x
                        result.y = wardCoord.y
                        result.absolute_heading = wardCoord.heading
                        result.level_name = getRouteTrackEndLevel()
                        print("(CheckRouteTracking) stopRouteTracking : normalizedRSSI = \(normalizedRSSI) // thresholdRSSI = \(thresholdRSSI)")
                        return normalizedRSSI >= thresholdRSSI ? (true, result) : (false, result)
                    } else {
                        return (false, result)
                    }
                } else {
                    return (false, result)
                }
            } else {
                return (false, result)
            }
        } else {
            return (false, result)
        }
    }
    
    func forcedStopRouteTracking(bleAvg: [String: Double], sec: Double) -> Bool {
        if isLastEntrancePosition && currentEntranceKey != "" {
            if let bleID = entranceInnerWardID[currentEntranceKey] {
                let scannedRSSI = bleAvg[bleID]
                if scannedRSSI == nil && checkForcedStopRouteTrackTimeStamp != 0 {
                    let timeDiff = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble() - checkForcedStopRouteTrackTimeStamp
                    if timeDiff >= sec*1000 {
                        return true
                    }
                } else {
                    checkForcedStopRouteTrackTimeStamp = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble()
                }
            }
        }
        return false
    }
    
    private func getRouteTrackEndLevel() -> String {
        if let entranceRouteData = entranceRoute[currentEntranceKey] {
            let entraneRouteLevel = entranceRouteData.routeLevel
            if !entraneRouteLevel.isEmpty {
                let levelName = entraneRouteLevel[entraneRouteLevel.count-1]
                return levelName
            }
        }
        return ""
    }

}
