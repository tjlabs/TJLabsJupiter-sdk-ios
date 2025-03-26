import Foundation
import UIKit
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate {
    
    // MARK: - Static Properties
    static var id: String = ""
    static var sectorId: Int = 0
    static var region: String = JupiterRegion.KOREA.rawValue
    static var os: String = CommonConstants.OPERATING_SYSTEM
    static var buildingName: String = ""
    static var levelName: String = ""
    static var scc: Double = 0.0
    static var x: Double = 0.0
    static var y: Double = 0.0
    static var absoluteHeading: Double = 0.0
    static var phase: Int = 1
    static var isPhaseBreak: Bool = false
    static var calTime: Double = 0.0
    static var currentUvd = UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    
    static var searchInfo = SearchInfo()
    static var bleOnlyPosition: Bool = false
    
    static var currentVelocity: Double = 0.0
    static var currentUserMode: UserMode = .MODE_PEDESTRIAN
    private var pressure: Double = 0.0
    
    private var uvdStopTimeStamp: Double = 0
    private var tjlabsResourceManager = TJLabsResourceManager()
    private var osrTimer: DispatchSourceTimer?
    private var simulationRfdTimer: DispatchSourceTimer?
    private var simulationUvdTimer: DispatchSourceTimer?
    
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    
    private var inputReceivedForce: [ReceivedForce] = []
    private var inputUserVelocity: [UserVelocity] = []
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
    static var tailIndex: Int = 0
    static var nodeNumberList = [Int]()
    static var nodeIndex = 0
    static var retry = false

    static var normalizationScale: Double = 1
    static var deviceMinRss: Double = -99
    static var standardMinRss: Double = -99
    
    static var isReadyPpResource = false
    static var isReadyEntranceResource = false

    static var isIndoor: Bool = false
    static var isRouteTrack: Bool = false
    static var validity: Bool = false
    static var validityFlag: Int = 0
    static var isVenus = false

    static var currentServerResult = FineLocationTrackingOutput()
    static var preServerResult = FineLocationTrackingOutput()
    static var preServerResultMobileTime: Double = 0

    static var drBuffer = [UserVelocity]()
    static var headSectionInfo = 0
    
    private var rfdEmptyMillis: Double = 0
    
    // MARK: - Static Methods
    static func getJupiterInput() -> FineLocationTrackingInput {
        return FineLocationTrackingInput(user_id: id, mobile_time: TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(), sector_id: sectorId, operating_system: os, building_name: buildingName, level_name_list: JupiterBuildingLevelChanager.makeLevelList(sectorId: sectorId, building: buildingName, level: levelName, x: x, y: y, mode: currentUserMode), phase: phase, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: normalizationScale, device_min_rss: Int(deviceMinRss), sc_compensation_list: getScCompensationList(phase: phase), tail_index: searchInfo.tailIndex, head_section_number: headSectionInfo, node_number_list: nodeNumberList, node_index: nodeIndex, retry: retry)
    }
    
    static func getJupiterResult() -> JupiterResult {
        buildingName = currentServerResult.building_name
        levelName = currentServerResult.level_name
        scc = currentServerResult.scc
        x = currentServerResult.x
        y = currentServerResult.y
        absoluteHeading = currentServerResult.absolute_heading
        
        // -- //
        if !isRouteTrack {
            if !isIndoor {
                isIndoor = x != 0 && y != 0 && buildingName != "" && levelName != "" && levelName != "B0"
            }
        } else {
            isIndoor = true
        }
        // -- //
        
        var currentResult = JupiterResult(
            mobile_time: TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(),
            building_name: buildingName,
            level_name: levelName,
            scc: scc,
            x: x,
            y: y,
            absolute_heading: absoluteHeading,
            phase: phase,
            calculated_time: calTime,
            index: currentUvd.index,
            velocity: currentVelocity,
            mode: currentUserMode,
            ble_only_position: false,
            isIndoor: false,
            validity: false,
            validity_flag: 0
        )
        
        return currentResult
    }
    
    static func getScCompensationList(phase : Int) -> [Double] {
        return phase <= 3 ? [1.0] : [1.01]
    }

    static func isPossibleReturnJupiterResult() -> Bool {
        return x != 0.0 && y != 0.0 && !buildingName.isEmpty && !levelName.isEmpty
    }

    // MARK: - Initialization
    init(region: String, id: String, sectorId: Int) {
        JupiterCalcManager.id = id
        JupiterCalcManager.sectorId = sectorId
        JupiterCalcManager.region = region
        tjlabsResourceManager.delegate = self
        tjlabsResourceManager.loadJupiterResource(region: region, sectorId: sectorId)
    }
    
    // MARK: - Timer
    func startTimer() {
        if (self.osrTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".osrTimer")
            self.osrTimer = DispatchSource.makeTimerSource(queue: queue)
            self.osrTimer!.schedule(deadline: .now(), repeating: JupiterTime.OSR_INTERVAL)
            self.osrTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.osrTimerUpdate()
            }
            self.osrTimer!.resume()
        }
    }
    
    func stopTimer() {
        self.osrTimer?.cancel()
        self.osrTimer = nil
    }
    
    private func osrTimerUpdate() {
        
    }

    // MARK: - Calculation Methods
    private func calcJupiterResult(mode: UserMode, uvd: UserVelocity) {
        if JupiterCalcManager.isRouteTrack {
            JupiterCalcManager.currentServerResult = JupiterRouteTracker.shared.startRouteTracking(uvd: uvd, curResult: JupiterCalcManager.currentServerResult)
            print("(CheckRouteTracking) : simul result // x = \(JupiterCalcManager.currentServerResult.x) , y = \(JupiterCalcManager.currentServerResult.y) , h = \(JupiterCalcManager.currentServerResult.absolute_heading)")
        } else {
            let rqIndex = mode == .MODE_VEHICLE ? JupiterMode.RQ_IDX_DR : JupiterMode.RQ_IDX_PDR
            
            if JupiterCalcManager.isVenus {
                if uvd.index % rqIndex == 0 {
                    phase1()
                }
            } else {
                let trajectoryBuffer = JupiterTrajectoryCalculator.updateTrajectoryBuffer(mode: mode, uvd: uvd, jupiterResult: JupiterCalcManager.getJupiterResult(), serverResult: JupiterCalcManager.currentServerResult)
                let searchInfo = mode == .MODE_VEHICLE ? JupiterTrajectoryCalculator.makeDrSearchInfo(phase: JupiterCalcManager.phase, trajectoryBuffer: trajectoryBuffer, lengthThreshold: JupiterMode.USER_TRAJECTORY_LENGTH_DR) : JupiterTrajectoryCalculator.makePdrSearchInfo(phase: JupiterCalcManager.phase, trajectoryBuffer: trajectoryBuffer, lengthThreshold: JupiterMode.USER_TRAJECTORY_LENGTH_PDR)
                print("(CheckJupiter) : serachInfo = \(searchInfo) , phase = \(JupiterCalcManager.phase)")
                
                switch (JupiterCalcManager.phase) {
                case 1:
                    if uvd.index % rqIndex == 0 {
                        phase1()
                    }
                case 3:
                    if uvd.index % rqIndex == 0 {
                        phase3(trajectoryBuffer: trajectoryBuffer, searchInfo: searchInfo)
                    }
                    break
                case 5:
                    break
                case 6:
                    break
                default:
                    break
                }
            }
        }
    }
    
    private func calcJupiterResultInStop(time: Double) {
        if !JupiterCalcManager.isPossibleReturnJupiterResult() {
            if (time - uvdStopTimeStamp >= 2000 && rfdEmptyMillis <= 10*JupiterTime.SECONDS_TO_MILLIS) {
                phase1()
                uvdStopTimeStamp = time
            }
        }
    }
    
    private func phase1() {
        JupiterCalculator.calculatePhase1(input: JupiterCalcManager.getJupiterInput(), completion: { [self] phaseCalculatorResult in
            updateServerResult(jupiterCalculatorResult: phaseCalculatorResult)
        })
    }
    
    private func phase3(trajectoryBuffer: [TrajectoryInfo], searchInfo: SearchInfo) {
        JupiterCalculator.calculatePhase3(input: JupiterCalcManager.getJupiterInput(), trajectoryBuffer: trajectoryBuffer, searchInfo: searchInfo, completion: { [self] phaseCalculatorResult in
            updateServerResult(jupiterCalculatorResult: phaseCalculatorResult)
        })
    }
    
    private func phase5() {
        
    }
    
    private func phase6() {
        
    }
    
    private func updateServerResult(jupiterCalculatorResult: JupiterCalculatorResults) {
        let selectedResult = JupiterResultSelector.selectBestResult(results: jupiterCalculatorResult.fltResultList)
        JupiterCalcManager.currentServerResult = selectedResult
        
        let paddingValues = JupiterCalcManager.currentUserMode == .MODE_VEHICLE ? JupiterMode.PADDING_VALUES_DR : JupiterMode.PADDING_VALUES_PDR
        let matchedResult = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: selectedResult.building_name, level: selectedResult.level_name, x: selectedResult.x, y: selectedResult.y, heading: selectedResult.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: true, mode: JupiterCalcManager.currentUserMode, paddingValues: paddingValues)
        print("(CheckJupiter) updatedServerResult : matchedResult = \(matchedResult)")
        
        JupiterCalcManager.currentServerResult.x = matchedResult.x
        JupiterCalcManager.currentServerResult.y = matchedResult.y
        JupiterCalcManager.currentServerResult.absolute_heading = matchedResult.heading
        
        let updatedPhase = JupiterPhaseController.controlPhase(inputPhase: JupiterCalcManager.phase, curResult: JupiterCalcManager.currentServerResult, preResult: JupiterCalcManager.preServerResult, trajectoryBuffer: jupiterCalculatorResult.inputTrajectoryInfo, drBuffer: JupiterStackManager.unitDRInfoBuffer, mode: JupiterCalcManager.currentUserMode)
        JupiterCalcManager.phase = updatedPhase
        print("(CheckJupiter) updatedServerResult : updatedPhase = \(updatedPhase)")
        
        JupiterCalcManager.preServerResult = JupiterCalcManager.currentServerResult
        JupiterCalcManager.preServerResultMobileTime = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble()
    }
    
    // MARK: - Set REC length
    public func setSendRfdLength(_ length: Int = 2) {
        sendRfdLength = length
    }
    
    public func setSendUvdLength(_ length: Int = 4) {
        sendUvdLength = length
    }
    
    func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        rfdGenerator = RFDGenerator(userId: JupiterCalcManager.id)
        uvdGenerator = UVDGenerator(userId: JupiterCalcManager.id)
        
        if ((rfdGenerator?.checkIsAvailableRfd()) != nil) {
            if ((uvdGenerator?.checkIsAvailableUvd()) != nil) {
                rfdGenerator?.generateRfd()
                rfdGenerator?.delegate = self
                
                uvdGenerator?.setUserMode(mode: mode)
                uvdGenerator?.generateUvd()
                uvdGenerator?.delegate = self
                
                rfdGenerator?.pressureProvider = { [weak self] in
                    return self?.pressure ?? 0.0
                }
                startTimer()
                completion(true, "")
            } else {
                completion(false, "checkIsAvailableUvd : false")
            }
        } else {
            completion(false, "checkIsAvailableRfd : false")
        }
    }
    
    func stopGenerator() {
        rfdGenerator?.stopRfdGeneration()
        uvdGenerator?.stopUvdGeneration()
        stopTimer()
    }
    
    // MARK: - Send Data to REC
    private func sendRfd(rfd: ReceivedForce) {
        let rfdURL = JupiterNetworkConstants.getRecRfdURL()
        inputReceivedForce.append(rfd)
        if inputReceivedForce.count >= sendRfdLength {
            JupiterNetworkManager.shared.postReceivedForce(url: rfdURL, input: inputReceivedForce) { [self] statusCode, returnedString, inputRfd in
//                print("(POST) RFD : statusCode = \(statusCode)")
            }
            inputReceivedForce.removeAll()
        }
    }
    
    private func sendUvd(uvd: UserVelocity) {
        let uvdURL = JupiterNetworkConstants.getRecUvdURL()
        inputUserVelocity.append(uvd)
        if inputUserVelocity.count >= sendUvdLength {
            JupiterNetworkManager.shared.postUserVelocity(url: uvdURL, input: inputUserVelocity) { [self] statusCode, returnedString, inputUvd in
//                print("(POST) UVD : statusCode = \(statusCode)")
            }
            inputUserVelocity.removeAll()
        }
    }
    
    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        handleRfd(rfd: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        sendRfd(rfd: rfd)
        if !JupiterCalcManager.isIndoor && !JupiterCalcManager.isRouteTrack {
            let checkStartRouteTrackResult = JupiterRouteTracker.shared.checkStartRouteTrack(bleAvg: rfd.ble, sec: 3)
            JupiterCalcManager.isRouteTrack = checkStartRouteTrackResult.0
            if JupiterCalcManager.isRouteTrack {
                let key = checkStartRouteTrackResult.1
                JupiterCalcManager.currentServerResult.building_name = String(key.split(separator: "_")[2])
            }
        }
        
        if JupiterCalcManager.isRouteTrack {
            let checkFinishRouteTrackResult = JupiterRouteTracker.shared.stopRouteTracking(curResult: JupiterCalcManager.currentServerResult, bleAvg: rfd.ble, normalizationScale: JupiterCalcManager.normalizationScale, deviceMinRss: JupiterCalcManager.deviceMinRss
                                                                                           , standardMinRss: JupiterCalcManager.standardMinRss)
            if checkFinishRouteTrackResult.0 {
                JupiterCalcManager.isRouteTrack = false
            }
            
            if JupiterRouteTracker.shared.forcedStopRouteTracking(bleAvg: rfd.ble, sec: 30) {
                JupiterCalcManager.isRouteTrack = false
            }
            
            JupiterCalcManager.currentServerResult = checkFinishRouteTrackResult.1
        }
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        //
    }
    
    func onRfdEmptyMillis(_ generator: TJLabsCommon.RFDGenerator, time: Double) {
        rfdEmptyMillis = time
    }
    
    // MARK: - UVDGeneratorDelegate Methods
    func onPressureResult(_ generator: UVDGenerator, hPa: Double) {
        // TODO: Handle pressure result
        pressure = hPa
    }
    func onUvdError(_ generator: UVDGenerator, error: String) {
        // TODO: Handle UVD error
    }
    func onUvdPauseMillis(_ generator: UVDGenerator, time: Double) {
        // TODO: Handle UVD pause
        calcJupiterResultInStop(time: time)
    }
    func onUvdResult(_ generator: UVDGenerator, mode: UserMode, userVelocity: UserVelocity) {
        sendUvd(uvd: userVelocity)
        JupiterCalcManager.currentUserMode = mode
        JupiterCalcManager.currentUvd = userVelocity
        uvdStopTimeStamp = 0
        JupiterStackManager.stackUnitDRInfo(unitDRInfo: userVelocity)
        calcJupiterResult(mode: mode, uvd: userVelocity)
    }
    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        JupiterCalcManager.currentVelocity = kmPh
    }
    func onMagNormSmoothingVarResult(_ generator: TJLabsCommon.UVDGenerator, value: Double) {
        //
    }
    
    // MARK: - TJLabsResourceManagerDelegate Methods
    func onBuildingLevelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, buildingLevelData: [String : [String]]) {
        if isOn {
            JupiterBuildingLevelChanager.setBuildingLevelData(buildingLevel: buildingLevelData)
        }
    }
    
    func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.PathPixelData?) {
        JupiterCalcManager.isReadyPpResource = isOn
        if isOn {
            if let ppData = data {
                JupiterPathMatchingCalculator.shared.region = JupiterCalcManager.region
                JupiterPathMatchingCalculator.shared.sectorId = JupiterCalcManager.sectorId
                JupiterPathMatchingCalculator.shared.setPathPixelData(key: key, data: ppData)
            }
        }
    }
    
    func onBuildingLevelImageData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: UIImage?) {
        //
    }
    
    func onScaleOffsetData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: [Double]?) {
        //
    }
    
    func onUnitData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: [TJLabsResource.UnitData]?) {
        //
    }
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.EntranceData?) {
        if isOn {
            if let entranceData = data {
                JupiterRouteTracker.shared.setEntranceData(region: JupiterCalcManager.region, sectorId: String(JupiterCalcManager.sectorId), data: entranceData)
            }
        }
    }
    
    func onEntranceRouteData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.EntranceRouteData?) {
        JupiterCalcManager.isReadyEntranceResource = isOn
        if isOn {
            if let entranceRouteData = data {
                JupiterRouteTracker.shared.setEntranceRouteData(key: key, data: entranceRouteData)
            }
        }
    }
    
    func onParamData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, data: TJLabsResource.ParameterData?) {
        //
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.GeofenceData?) {
        if isOn {
            if let geofenceData = data {
                let levelChangeArea = geofenceData.levelChangeArea
                let entranceMatchingArea = geofenceData.entranceMatchingArea
                JupiterBuildingLevelChanager.setLevelChangeArea(key: key, data: levelChangeArea)
                JupiterPathMatchingCalculator.shared.setEntranceMatchingData(key: key, data: entranceMatchingArea)
            }
        }
    }
    
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        //
    }
}
