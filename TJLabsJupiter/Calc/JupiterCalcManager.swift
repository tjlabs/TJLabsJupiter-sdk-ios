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
    static var phase: Int = 1
    
    static var currentUvd = UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    static var currentUserMask = UserMask(user_id: "", mobile_time: 0, section_number: 0, index: 0, x: 0, y: 0, absolute_heading: 0)
    static var pastUvd = UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    
    static var searchInfo = SearchInfo()
    static var bleOnlyPosition: Bool = false
    
    static var currentVelocity: Double = 0.0
    static var currentUserMode: UserMode = .MODE_PEDESTRIAN
    private var pressure: Double = 0.0
    
    private var uvdStopTimeStamp: Double = 0
    private var tjlabsResourceManager = TJLabsResourceManager()
    private var osrTimer: DispatchSourceTimer?
    
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    
    static var tailIndex: Int = 0
    static var nodeNumberList = [Int]()
    static var nodeIndex = 0
    static var retry = false
    
    static var isReadyPpResource = false
    static var isReadyEntranceResource = false
    
    static var isPhaseBreak: Bool = false
    static var isIndoor: Bool = false
    static var isRouteTrack: Bool = false
    static var validity: Bool = false
    static var validityFlag: Int = 0
    static var isDRMode = false
    static var isVenus = false
    static var isActiveKf = false
    static var isInRecoveryProcess = false
    static var recoveryIndex = 0
    static var stableModeInitFlag = true
    static var isDRModeRqInfoSaved = false
    static var drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: [], stableInfo: StableInfo(tail_index: -1, head_section_number: 0, node_number_list: []), nodeCandidatesInfo: NodeCandidateInfo(), prevNodeInfo: PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: 0, userHeading: 0))
    
    static var curJupiterPathMatchingResult = FineLocationTrackingOutput()
    static var preJupiterPathMatchingResult = FineLocationTrackingOutput()
    static var curJupiterResult = FineLocationTrackingOutput()
    static var preJupiterResult = FineLocationTrackingOutput()
    
    static var preServerResult = FineLocationTrackingOutput()
    static var preServerResultMobileTime: Double = 0

    static var drBuffer = [UserVelocity]()
    static var headSectionInfo = 0
    
    private var rfdEmptyMillis: Double = 0
    
    private var paddingValues = JupiterMode.PADDING_VALUES_DR
    private var pathMatchingCondition = PathMatchingCondition()
    
    // MARK: - Static Methods
    static func getJupiterInput() -> FineLocationTrackingInput {
        let buildingName = curJupiterResult.building_name
        let levelName = curJupiterResult.level_name
        let x = curJupiterResult.x
        let y = curJupiterResult.y
        
        return FineLocationTrackingInput(user_id: id, mobile_time: TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(), sector_id: sectorId, operating_system: os, building_name: buildingName, level_name_list: JupiterBuildingLevelChanger.makeLevelList(sectorId: sectorId, building: buildingName, level: levelName, x: x, y: y, mode: currentUserMode), phase: phase, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: JupiterRssCompensator.normalizationScale, device_min_rss: Int(JupiterRssCompensator.deviceMinRss), sc_compensation_list: getScCompensationList(phase: phase), tail_index: searchInfo.tailIndex, head_section_number: headSectionInfo, node_number_list: nodeNumberList, node_index: nodeIndex, retry: retry)
    }
    
    static func getJupiterResult() -> JupiterResult {
        let buildingName = curJupiterPathMatchingResult.building_name
        let levelName = curJupiterPathMatchingResult.level_name
        let scc = curJupiterPathMatchingResult.scc
        let x = curJupiterPathMatchingResult.x
        let y = curJupiterPathMatchingResult.y
        let absoluteHeading = curJupiterPathMatchingResult.absolute_heading
        let calTime = curJupiterPathMatchingResult.calculated_time
        
        // -- //
        if !isRouteTrack {
            if !isIndoor {
                isIndoor = x != 0 && y != 0 && buildingName != "" && levelName != "" && levelName != "B0"
            }
        } else {
            isIndoor = true
        }
        // -- //
        
        let currentResult = JupiterResult(
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
        let buildingName = curJupiterResult.building_name
        let levelName = curJupiterResult.level_name
        let x = curJupiterResult.x
        let y = curJupiterResult.y
        
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
            JupiterCalcManager.curJupiterResult = JupiterRouteTracker.shared.startRouteTracking(uvd: uvd, curResult: JupiterCalcManager.curJupiterResult)
            print("(CheckRouteTracking) : simul result // \(JupiterCalcManager.curJupiterResult.building_name) \(JupiterCalcManager.curJupiterResult.level_name) , x = \(JupiterCalcManager.curJupiterResult.x) , y = \(JupiterCalcManager.curJupiterResult.y) , h = \(JupiterCalcManager.curJupiterResult.absolute_heading)")
        } else {
            let rqIndex = mode == .MODE_VEHICLE ? JupiterMode.RQ_IDX_DR : JupiterMode.RQ_IDX_PDR
            
            if JupiterCalcManager.isVenus {
                if uvd.index % rqIndex == 0 {
                    phase1(completion: { phase1Result in
                        self.makeTemporalResult(input: phase1Result, isStableMode: false, mustInSameLink: false, updateType: .NONE, pathMatchingType: .NARROW)
                    })
                }
            } else {
                if JupiterCalcManager.isActiveKf {
                    let tuResult = updateResultFromTimeUpdate(mode: mode, uvd: uvd, pastUvd: JupiterCalcManager.pastUvd)
                    JupiterCalcManager.curJupiterResult.x = tuResult.x
                    JupiterCalcManager.curJupiterResult.y = tuResult.y
                    JupiterCalcManager.curJupiterResult.absolute_heading = tuResult.absolute_heading
                    
                    let isNeedUpateAnchorNode = JupiterSectionController.extendedCheckIsNeedAnchorNodeUpdate(uvdLength: uvd.length, curHeading: JupiterCalcManager.curJupiterResult.absolute_heading, preHeading: JupiterCalcManager.preJupiterResult.absolute_heading)
//                    print("(CheckIsAnchorNodeUpdate) : curHeaidng = \(JupiterCalcManager.curJupiterResult.absolute_heading) // preHeading = \(JupiterCalcManager.preJupiterResult.absolute_heading)")
                    if isNeedUpateAnchorNode {
                        JupiterNodeChecker.updateAnchorNode(fltResult: JupiterCalcManager.curJupiterResult, mode: mode, sectionNumber: JupiterSectionController.sectionNumber)
                    }
                    self.makeTemporalResult(input: tuResult, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .NARROW)
                }
                
                let trajectoryBuffer = JupiterTrajectoryCalculator.updateTrajectoryBuffer(mode: mode, uvd: uvd, jupiterResult: JupiterCalcManager.getJupiterResult(), serverResult: JupiterCalcManager.curJupiterResult)
                let searchInfo = mode == .MODE_VEHICLE ? JupiterTrajectoryCalculator.makeDrSearchInfo(phase: JupiterCalcManager.phase, trajectoryBuffer: trajectoryBuffer, lengthThreshold: JupiterMode.USER_TRAJECTORY_LENGTH_DR) : JupiterTrajectoryCalculator.makePdrSearchInfo(phase: JupiterCalcManager.phase, trajectoryBuffer: trajectoryBuffer, lengthThreshold: JupiterMode.USER_TRAJECTORY_LENGTH_PDR)
                JupiterCalcManager.searchInfo = searchInfo
//                print("(CheckJupiter) : serachInfo = \(searchInfo) , phase = \(JupiterCalcManager.phase)")
                
                switch (JupiterCalcManager.phase) {
                case 1:
                    if uvd.index % rqIndex == 0 {
                        phase1(completion: { selectedResult in
                            JupiterCalcManager.curJupiterResult = selectedResult
                        })
                    }
                case 3:
                    if uvd.index % rqIndex == 0 {
                        phase3(trajectoryBuffer: trajectoryBuffer, searchInfo: JupiterCalcManager.searchInfo, completion: { selectedResult in
                            JupiterCalcManager.curJupiterResult = selectedResult
                        })
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
        
//        let paddingValues = mode == .MODE_VEHICLE ? JupiterMode.PADDING_VALUES_DR : JupiterMode.PADDING_VALUES_PDR
        let pmResults = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: JupiterCalcManager.curJupiterResult.building_name, level: JupiterCalcManager.curJupiterResult.level_name, x: JupiterCalcManager.curJupiterResult.x, y: JupiterCalcManager.curJupiterResult.y, heading: JupiterCalcManager.curJupiterResult.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: true, mode: mode, paddingValues: self.paddingValues)
        
//        JupiterCalcManager.pastUvd = uvd
//        JupiterCalcManager.preJupiterResult = JupiterCalcManager.curJupiterResult
        
        if JupiterCalcManager.isRouteTrack {
            JupiterCalcManager.curJupiterPathMatchingResult = JupiterCalcManager.curJupiterResult
        } else {
            if pmResults.0 {
                JupiterCalcManager.curJupiterPathMatchingResult = JupiterCalcManager.curJupiterResult
                JupiterCalcManager.curJupiterPathMatchingResult.x = pmResults.1.x
                JupiterCalcManager.curJupiterPathMatchingResult.y = pmResults.1.y
                JupiterCalcManager.curJupiterPathMatchingResult.absolute_heading = pmResults.1.heading
            }
        }
    }
    
    private func calcJupiterResultInStop(time: Double) {
        if !JupiterCalcManager.isPossibleReturnJupiterResult() {
            if (time - uvdStopTimeStamp >= 2000 && rfdEmptyMillis <= 10*JupiterTime.SECONDS_TO_MILLIS) {
                phase1(completion: { selectedResult in
                    JupiterCalcManager.curJupiterResult = selectedResult
                })
                uvdStopTimeStamp = time
            }
        }
    }
    
    private func phase1(completion: @escaping (FineLocationTrackingOutput) -> Void) {
        JupiterCalculator.calculatePhase1(input: JupiterCalcManager.getJupiterInput(), completion: { [self] phaseCalculatorResult in
            let selecteResult = updateResultFromFlt(jupiterCalculatorResults: phaseCalculatorResult)
            completion(selecteResult)
        })
    }
    
    private func phase3(trajectoryBuffer: [TrajectoryInfo], searchInfo: SearchInfo, completion: @escaping (FineLocationTrackingOutput) -> Void) {
        JupiterCalculator.calculatePhase3(input: JupiterCalcManager.getJupiterInput(), trajectoryBuffer: trajectoryBuffer, searchInfo: searchInfo, completion: { [self] phaseCalculatorResult in
            let selecteResult = updateResultFromFlt(jupiterCalculatorResults: phaseCalculatorResult)
            completion(selecteResult)
        })
    }
    
    private func phaseBreakInPhase4(fltResult: FineLocationTrackingOutput, isUpdatePhaseBreakResult: Bool) {
        JupiterCalcManager.phase = 1
        JupiterCalcManager.isPhaseBreak = true
        uvdGenerator?.updateDrVelocityScale(scale: 1)
    }
    
    private func phase5() {
        
    }
    
    private func phase6() {
        
    }
    
    private func updateResultFromTimeUpdate(mode: UserMode, uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput {
        var result = FineLocationTrackingOutput()
        if mode == .MODE_PEDESTRIAN {
            result = JupiterKalmanFilter.pdrTimeUpdate(region: JupiterCalcManager.region, sectorId: JupiterCalcManager.sectorId, uvd: uvd, pastUvd: pastUvd)
        } else {
            result = JupiterKalmanFilter.drTimeUpdate(region: JupiterCalcManager.region, sectorId: JupiterCalcManager.sectorId, uvd: uvd, pastUvd: pastUvd)
        }
        return result
    }
    
    private func updateResultFromFlt(jupiterCalculatorResults: JupiterCalculatorResults) -> FineLocationTrackingOutput {
        var selectedResult = JupiterResultSelector.selectBestResult(results: jupiterCalculatorResults.fltResultList)
//        let paddingValues = JupiterCalcManager.currentUserMode == .MODE_VEHICLE ? JupiterMode.PADDING_VALUES_DR : JupiterMode.PADDING_VALUES_PDR
        let pmResults = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: selectedResult.building_name, level: selectedResult.level_name, x: selectedResult.x, y: selectedResult.y, heading: selectedResult.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: true, mode: JupiterCalcManager.currentUserMode, paddingValues: self.paddingValues)
        print("(CheckJupiter) updatedServerResult : pmResults = \(pmResults)")
        
        let pmXyhs: xyhs = pmResults.1
        selectedResult.x = pmXyhs.x
        selectedResult.y = pmXyhs.y
        selectedResult.absolute_heading = pmXyhs.heading
        
        let updatedPhase = JupiterPhaseController.controlPhase(inputPhase: JupiterCalcManager.phase, curResult: JupiterCalcManager.curJupiterResult, preResult: JupiterCalcManager.preServerResult, trajectoryBuffer: jupiterCalculatorResults.inputTrajectoryInfo, drBuffer: JupiterStackManager.unitDRInfoBuffer, mode: JupiterCalcManager.currentUserMode)
        JupiterCalcManager.phase = updatedPhase
        
        if !JupiterCalcManager.isActiveKf && JupiterCalcManager.phase == JupiterPhase.PHASE_6 {
            JupiterCalcManager.isActiveKf = true
            JupiterKalmanFilter.updateTuResult(result: selectedResult)
        }

        JupiterCalcManager.preServerResult = selectedResult
        JupiterCalcManager.preServerResultMobileTime = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble()
        
        return selectedResult
    }
    
    private func reloadPathPixelData(key: String) {
        if let ppDataIsLoaded = JupiterPathMatchingCalculator.shared.pathPixelDataIsLoaded[key] {
            let isLoaded = ppDataIsLoaded.isLoaded
            if !isLoaded {
                tjlabsResourceManager.updatePathPixelData(key: key, URL: ppDataIsLoaded.URL)
            }
        }
    }
    
    private func makeTemporalResult(input: FineLocationTrackingOutput, isStableMode: Bool, mustInSameLink: Bool, updateType: UpdateNodeLinkType, pathMatchingType: PathMatchingType) {
        var result = input
        var isUseHeading = false
        if (result.x != 0 || result.y != 0 && result.building_name != "" && result.level_name != "") {
            let buildingName: String = result.building_name
            let levelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: result.level_name)
            result.level_name = levelName
            var isPmFailed = false
            
            if (JupiterCalcManager.currentUserMode == .MODE_PEDESTRIAN) {
                var headingRange = JupiterMode.HEADING_RANGE
                var paddings = paddingValues
                if (pathMatchingType == PathMatchingType.NARROW) {
                    isUseHeading = true
                    headingRange -= 10
                    paddings = Array(repeating: 1.5, count: 4)
                }
                let pmResult = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterCalcManager.region, sectorId: JupiterCalcManager.sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: headingRange, isUseHeading: isUseHeading, mode: .MODE_PEDESTRIAN, paddingValues: paddings)
                
                if (pmResult.0) {
                    result.x = pmResult.1.x
                    result.y = pmResult.1.y
                    result.absolute_heading = pmResult.1.heading
                } else {
                    let key = "\(JupiterCalcManager.region)_\(JupiterCalcManager.sectorId)_\(buildingName)_\(levelName)"
                    reloadPathPixelData(key: key)
                    isPmFailed = true
                }
                isUseHeading = false
            } else {
                isUseHeading = !JupiterCalcManager.isVenus
                let pmResult = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterCalcManager.region, sectorId: JupiterCalcManager.sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: isUseHeading, mode: .MODE_VEHICLE, paddingValues: paddingValues)
                
                if (pmResult.0) {
                    uvdGenerator?.updateDrVelocityScale(scale: pmResult.1.scale)
                    result.x = pmResult.1.x
                    result.y = pmResult.1.y
                    result.absolute_heading = pmResult.1.heading
                } else {
                    let key = "\(JupiterCalcManager.region)_\(JupiterCalcManager.sectorId)_\(buildingName)_\(levelName)"
                    reloadPathPixelData(key: key)
                    isPmFailed = true
                }
            }
            
            
            if (mustInSameLink && levelName != "B0") {
                let directions = JupiterNodeChecker.linkDirections
                let linkCoord = JupiterNodeChecker.linkCoord
                if (directions.count == 2) {
                    let MARGIN: Double = 30
                    if (directions.contains(0) && directions.contains(180)) {
                        // 이전 y축 값과 현재 y값은 같아야 함
                        let diffHeading = TJLabsUtilFunctions.shared.compensateDegree(abs(result.absolute_heading - directions[0]))
                        if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                            result.y = linkCoord[1]
                        }
                        
                    } else if (directions.contains(90) && directions.contains(270)) {
                        // 이전 x축 값과 현재 x축 값은 같아야 함
                        let diffHeading = TJLabsUtilFunctions.shared.compensateDegree(abs(result.absolute_heading - directions[0]))
                        if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                            result.x = linkCoord[0]
                        }
                    }
                }
            }

            if (isUseHeading && isStableMode && !JupiterCalcManager.isPhaseBreak) {
                let diffX = result.x - JupiterCalcManager.curJupiterPathMatchingResult.x
                let diffY = result.y - JupiterCalcManager.curJupiterPathMatchingResult.y
                let diffNorm = sqrt(diffX*diffX + diffY*diffY)
                if diffNorm >= 2 {
                    JupiterKalmanFilter.updateTuResult(result: result)
                    JupiterKalmanFilter.updateTuResultNow(result: result)
                }
            }

            if (isPmFailed) {
                if (JupiterCalcManager.isActiveKf) {
                    result = JupiterCalcManager.preJupiterResult
                    let pmResult = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterCalcManager.region, sectorId: JupiterCalcManager.sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: isUseHeading, mode: .MODE_VEHICLE, paddingValues: paddingValues)
                    if pmResult.0 {
                        result.x = pmResult.1.x
                        result.y = pmResult.1.y
                    }
                }
            }

            if (JupiterCalcManager.isActiveKf) {
                JupiterNodeChecker.updateNodeAndLinkInfo(uvdIndex: JupiterCalcManager.currentUvd.index, currentResult: result, pastResult: JupiterCalcManager.preJupiterPathMatchingResult, mode: JupiterCalcManager.currentUserMode, updateType: updateType)
                paddingValues = JupiterNodeChecker.getPaddingValues(mode: JupiterCalcManager.currentUserMode, isPhaseBreak: JupiterCalcManager.isPhaseBreak)
            }

            JupiterCalcManager.currentUserMask = UserMask(user_id: JupiterCalcManager.id,
                                                          mobile_time: TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(),
                                                          section_number: JupiterSectionController.sectionNumber,
                                                          index: JupiterCalcManager.currentUvd.index,
                                                          x: Int(result.x), y: Int(result.y),
                                                          absolute_heading: result.absolute_heading)
            JupiterStackManager.stackUserMaskPathTrajMatching(userMask: JupiterCalcManager.currentUserMask)
            
            if (!JupiterCalcManager.isDRMode) {
                JupiterCalcManager.isDRMode = JupiterBuildingLevelChanger.checkInSectorDRModeArea(fltResult: result, passedNodeInfo: JupiterNodeChecker.currentPassedNodeInfo)
            } else {
                JupiterCalcManager.isDRMode = JupiterBuildingLevelChanger.checkInSectorDRModeArea(fltResult: result, passedNodeInfo: JupiterNodeChecker.currentPassedNodeInfo)
                if (!JupiterCalcManager.isDRMode) {
                    JupiterCalcManager.isDRModeRqInfoSaved = false
                    JupiterCalcManager.drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: [], stableInfo: StableInfo(tail_index: -1, head_section_number: 0, node_number_list: []), nodeCandidatesInfo: NodeCandidateInfo(), prevNodeInfo: PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: 0, userHeading: 0))
                }
            }

            if (isStableMode) {
                if (JupiterCalcManager.stableModeInitFlag) {
                    JupiterSectionController.anchorTailIndex = result.index
                    JupiterCalcManager.stableModeInitFlag = false
                }

                JupiterDataBatchSender.sendUserMask(userMask: JupiterCalcManager.currentUserMask)
                JupiterStackManager.stackUserMask(userMask: JupiterCalcManager.currentUserMask)
                JupiterStackManager.stackUserUniqueMask(userMask: JupiterCalcManager.currentUserMask)
                JupiterStackManager.stackUserUniqueMask(userMask: JupiterCalcManager.currentUserMask)
                JupiterStackManager.stackUserMaskForDisplay(userMask: JupiterCalcManager.currentUserMask)


                if (JupiterCalcManager.isInRecoveryProcess) {
                    JupiterCalcManager.isInRecoveryProcess = false
                    JupiterCalcManager.recoveryIndex = JupiterCalcManager.currentUvd.index
                    pathMatchingCondition = PathMatchingCondition()
                } else {
                    if (JupiterCalcManager.currentUserMode == .MODE_PEDESTRIAN) {
                        pathMatchingCondition = JupiterStackManager.checkIsNeedPathTrajMatching(recoveryIndex: JupiterCalcManager.recoveryIndex)
                    } else {
                        if (JupiterCalcManager.isDRMode){
                            if(JupiterStackManager.checkIsBadCase(recoveryIndex: JupiterCalcManager.recoveryIndex) && !JupiterCalcManager.isPhaseBreak) {
                                if (JupiterBuildingLevelChanger.checkCoordInSectorDRModeArea(fltResult: result)) {
                                    phaseBreakInPhase4(fltResult: result, isUpdatePhaseBreakResult: true)
                                }
                            }
                        }
                    }
                }
            }

            JupiterCalcManager.curJupiterResult = result

            if (!JupiterMode.DEFAULT_HEADINGS.contains(result.absolute_heading)) {
                let diffX = input.x - result.x
                let diffY = input.y - result.y
                let diffNorm = sqrt(diffX*diffX + diffY*diffY)
                if (diffNorm >= 2) {
                    JupiterKalmanFilter.updateTuResult(result: result)
                    JupiterKalmanFilter.updateTuResultNow(result: result)
                }
            }
        }
    }
    
    // MARK: - Set REC length
    public func setSendRfdLength(_ length: Int = 2) {
        JupiterDataBatchSender.sendRfdLength = length
    }
    
    public func setSendUvdLength(_ length: Int = 4) {
        JupiterDataBatchSender.sendUvdLength = length
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
        JupiterRssCompensator.saveNormalizationScaleToCache(sector_id: JupiterCalcManager.sectorId)
        stopTimer()
    }

    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        handleRfd(rfd: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        JupiterDataBatchSender.sendRfd(rfd: rfd)
        if !JupiterCalcManager.isIndoor && !JupiterCalcManager.isRouteTrack {
            let checkStartRouteTrackResult = JupiterRouteTracker.shared.checkStartRouteTrack(bleAvg: rfd.ble, sec: 3)
            JupiterCalcManager.isRouteTrack = checkStartRouteTrackResult.0
            if JupiterCalcManager.isRouteTrack {
                let key = checkStartRouteTrackResult.1
                let routeTrackData = key.split(separator: "_")
                print("(CheckRouteTracking) : routeTrackData = \(routeTrackData)")
                JupiterCalcManager.curJupiterResult.building_name = String(routeTrackData[1])
            }
        }
        
        if JupiterCalcManager.isRouteTrack {
            let checkFinishRouteTrackResult = JupiterRouteTracker.shared.stopRouteTracking(curResult: JupiterCalcManager.curJupiterResult, bleAvg: rfd.ble, normalizationScale: JupiterRssCompensator.normalizationScale, deviceMinRss: JupiterRssCompensator.deviceMinRss
                                                                                           , standardMinRss: JupiterRssCompensator.standardMinRss)
            if checkFinishRouteTrackResult.0 {
                print("(CheckRouteTracking) : Route-tracking Finished // \(checkFinishRouteTrackResult.1.building_name) \(checkFinishRouteTrackResult.1.level_name) , [\(checkFinishRouteTrackResult.1.x),\(checkFinishRouteTrackResult.1.y),\(checkFinishRouteTrackResult.1.absolute_heading)]")
                // RouteTrack Finshid (Normal)
                JupiterCalcManager.isRouteTrack = false
                JupiterCalcManager.isActiveKf = true
                JupiterCalcManager.phase = 6
                JupiterCalcManager.curJupiterResult = checkFinishRouteTrackResult.1
                JupiterCalcManager.curJupiterPathMatchingResult = checkFinishRouteTrackResult.1
                JupiterKalmanFilter.updateTuResult(result: checkFinishRouteTrackResult.1)
            }
            
            if JupiterRouteTracker.shared.forcedStopRouteTracking(bleAvg: rfd.ble, sec: 30) {
                // RouteTrack Finshid (Force)
                JupiterCalcManager.isRouteTrack = false
            }
        }
        
        if !rfd.ble.isEmpty {
            let bleAvg = rfd.ble
            JupiterRssCompensator.refreshWardMinRssi(bleData: bleAvg)
            JupiterRssCompensator.refreshWardMaxRssi(bleData: bleAvg)
            let minRssi = JupiterRssCompensator.getMinRssi()
            let maxRssi = JupiterRssCompensator.getMaxRssi()
            
            let diffMinMaxRssi = abs(maxRssi - minRssi)
            if minRssi <= JupiterRssCompensation.DEVICE_MIN_UPDATE_THRESHOLD {
                JupiterRssCompensator.deviceMinRss = minRssi
            }
            JupiterRssCompensator.stackTimeAfterResponse()
            JupiterRssCompensator.estimateNormalizationScale(isGetFirstResponse: JupiterCalcManager.isPossibleReturnJupiterResult(), isIndoor: JupiterCalcManager.isIndoor, currentLevel: JupiterCalcManager.curJupiterPathMatchingResult.level_name, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
            if JupiterRssCompensator.isScaleConverged && !JupiterRssCompensator.isScaleSaved {
                JupiterRssCompensator.saveNormalizationScaleToCache(sector_id: JupiterCalcManager.sectorId)
                JupiterRssCompensator.isScaleSaved = true
            }
            
        }
        
        if !JupiterCalcManager.isIndoor {
            JupiterRssCompensator.initializeTimeStack()
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
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds()
        JupiterDataBatchSender.sendUvd(uvd: userVelocity)
        JupiterCalcManager.currentUserMode = mode
        JupiterCalcManager.currentUvd = userVelocity
        uvdStopTimeStamp = 0
        JupiterStackManager.stackUnitDRInfo(unitDRInfo: userVelocity)
        calcJupiterResult(mode: mode, uvd: userVelocity)
        
        JupiterCalcManager.pastUvd = userVelocity
        JupiterCalcManager.preJupiterResult = JupiterCalcManager.curJupiterResult
        JupiterCalcManager.preJupiterPathMatchingResult = JupiterCalcManager.curJupiterPathMatchingResult
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
            JupiterBuildingLevelChanger.setBuildingLevelData(buildingLevel: buildingLevelData)
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
    
    func onPathPixelDataLoaded(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.PathPixelDataIsLoaded?) {
        if isOn {
            if let ppDataIsLoaded = data {
                JupiterPathMatchingCalculator.shared.setPathPixelDataIsLoaded(key: key, data: ppDataIsLoaded)
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
        if isOn {
            if let paramData = data {
                JupiterRssCompensator.setStandardMinMax(minMax: paramData.standard_rss)
            }
        }
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.GeofenceData?) {
        if isOn {
            if let geofenceData = data {
                let levelChangeArea = geofenceData.levelChangeArea
                let sectorDrModeArea = geofenceData.drModeArea
                let entranceMatchingArea = geofenceData.entranceMatchingArea
                JupiterBuildingLevelChanger.setLevelChangeArea(key: key, data: levelChangeArea)
                JupiterBuildingLevelChanger.setSectorDRModeArea(key: key, data: sectorDrModeArea)
                JupiterPathMatchingCalculator.shared.setEntranceMatchingData(key: key, data: entranceMatchingArea)
            }
        }
    }
    
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        //
    }
}
