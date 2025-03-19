import Foundation
import UIKit
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate {
    // MARK: - Static Properties
    static var fltRequestIndex = 4
    static var id: String = ""
    static var sectorId: Int = 0
    static var os: String = CommonConstants.OPERATING_SYSTEM
    static var buildingName: String = ""
    static var levelName: String = ""
    static var scc: Double = 0.0
    static var x: Double = 0.0
    static var y: Double = 0.0
    static var absoluteHeading: Double = 0.0
    static var phase: Int = 1
    static var isPhaseBreak: Bool = false
    static var phaseBreakFineLocationTrackingResult = FineLocationTrackingOutput()
    
    static var calTime: Double = 0.0
    static var currentUvd = UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    static var searchRange = [Int]()
    static var searchDirectionList = [Int]()
    static var bleOnlyPosition: Bool = false
    static var isIndoor: Bool = false
    static var validity: Bool = false
    static var validityFlag: Int = 0
    static var currentVelocity: Double = 0.0
    static var currentUserMode: UserMode = .MODE_PEDESTRIAN
    static var tailIndex: Int = 0
    
    private var uvdStopTimeStamp: Double = 0
    private var tjlabsResourceManager = TJLabsResourceManager()
    private var osrTimer: DispatchSourceTimer?
    
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    
    private var pressure: Double = 0.0
    private var inputReceivedForce: [ReceivedForce] = []
    private var inputUserVelocity: [UserVelocity] = []
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
    // MARK: - Static Methods
    static func getPhaseBreak() -> Bool {
        if isPhaseBreak {
            isPhaseBreak = false
            return true
        } else {
            return false
        }
    }
    
    static func getJupiterResult() -> JupiterResult {
        return JupiterResult(
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
    }

    static func getLatestFineLocationTrackingInput() -> FineLocationTrackingInput {
        return FineLocationTrackingInput(
            user_id: id,
            mobile_time: TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(),
            sector_id: sectorId,
            operating_system: os,
            building_name: buildingName,
            level_name_list: [levelName],
            phase: phase,
            search_range: searchRange,
            search_direction_list: searchDirectionList,
            normalization_scale: 1.0,
            device_min_rss: -99,
            sc_compensation_list: [1.0],
            tail_index: tailIndex,
            head_section_number: 0,
            node_number_list: [],
            node_index: 0,
            retry: false)
    }

    static func isPossibleReturnJupiterResult() -> Bool {
        return x != 0.0 && y != 0.0 && !buildingName.isEmpty && !levelName.isEmpty
    }

    // MARK: - Properties
    private let phase3BreakScc: Double = 0.62
    private var preServerResultMobileTime: Int = 0
    private var prePhase: Int = 1

    // MARK: - Initialization
    init(region: String, id: String, sectorId: Int) {
        JupiterCalcManager.id = id
        JupiterCalcManager.sectorId = sectorId
        tjlabsResourceManager.delegate = self
//        tjlabsResourceManager.loadJupiterResource(region: .KOREA, sectorId: JupiterCalcManager.sectorId)
    }

    // MARK: - Calculation Methods
    private func calcJupiterResult() {
        switch JupiterCalcManager.phase {
        case 1:
            calculatePhase1()
        case 2:
            // TODO: Implement Phase 2
            break
        case 3:
            calculatePhase3()
            break
        case 5:
            // TODO: Implement Phase 5
            break
        case 6:
            // TODO: Implement Phase 6
            break
        default:
            break
        }
        
        if JupiterCalcManager.phase < 2 && self.prePhase >= 2 {
            JupiterCalcManager.isPhaseBreak = true
        }
        self.prePhase = JupiterCalcManager.phase
    }
    
    private func calcJupiterResultInStop(time: Double) {
        if !JupiterCalcManager.isPossibleReturnJupiterResult() {
            if (time - uvdStopTimeStamp >= 2000) {
                uvdStopTimeStamp = time
            }
        }
    }

    private func calculatePhase1() {
        if (JupiterCalcManager.currentUvd.index % JupiterCalcManager.fltRequestIndex) == 0 {
            let phase1Input = JupiterCalcManager.getLatestFineLocationTrackingInput()
            let fltInput = FLT(fltInput: phase1Input, trajInfoList: [], searchInfo: SearchInfo())
            JupiterNetworkManager.shared.postFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: fltInput, completion: { [self] statusCode, returnedString, input in
                if statusCode == 200 {
                    let decodedResult = decodeFineLocationTrackingOutputList(jsonString: returnedString)
                    let result = decodedResult.1.flt_outputs
                    let fltResult = result.isEmpty ? FineLocationTrackingOutput() : result[0]
                    if decodedResult.0 && fltResult.x != 0 || fltResult.y != 0 && fltResult.mobile_time >= self.preServerResultMobileTime {
                        JupiterCalcManager.buildingName = fltResult.building_name
                        JupiterCalcManager.levelName = fltResult.level_name
                        JupiterCalcManager.scc = fltResult.scc
                        JupiterCalcManager.x = fltResult.x
                        JupiterCalcManager.y = fltResult.y
                        JupiterCalcManager.absoluteHeading = fltResult.absolute_heading
                        JupiterCalcManager.calTime = fltResult.calculated_time
                        JupiterCalcManager.phase = fltResult.scc >= phase3BreakScc ? 3 : 1
                        JupiterCalcManager.phaseBreakFineLocationTrackingResult = fltResult
                        preServerResultMobileTime = fltResult.mobile_time
                    }
                }
            })
        }
    }
    
    private func calculatePhase3() {
        if (JupiterCalcManager.currentUvd.index % JupiterCalcManager.fltRequestIndex) == 0 {
            let phase3Input = JupiterCalcManager.getLatestFineLocationTrackingInput()
            let fltInput = FLT(fltInput: phase3Input, trajInfoList: [], searchInfo: SearchInfo())
            JupiterNetworkManager.shared.postFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: fltInput, completion: { [self] statusCode, returnedString, input in
                if statusCode == 200 {
                    let decodedResult = decodeFineLocationTrackingOutputList(jsonString: returnedString)
                    let result = decodedResult.1.flt_outputs
                    let fltResult = result.isEmpty ? FineLocationTrackingOutput() : result[0]
                    if decodedResult.0 && fltResult.x != 0 || fltResult.y != 0 && fltResult.mobile_time >= self.preServerResultMobileTime {
                        JupiterCalcManager.buildingName = fltResult.building_name
                        JupiterCalcManager.levelName = fltResult.level_name
                        JupiterCalcManager.scc = fltResult.scc
                        JupiterCalcManager.x = fltResult.x
                        JupiterCalcManager.y = fltResult.y
                        JupiterCalcManager.absoluteHeading = fltResult.absolute_heading
                        JupiterCalcManager.calTime = fltResult.calculated_time
                        if fltResult.scc < 0.45 {
                            JupiterCalcManager.phase = 1
                        }
                        JupiterCalcManager.phaseBreakFineLocationTrackingResult = fltResult
                        preServerResultMobileTime = fltResult.mobile_time
                    }
                }
            })
        }
    }
    
    // MARK: - Decode FLT output
    func decodeFineLocationTrackingOutputList(jsonString: String) -> (Bool, FineLocationTrackingOutputList) {
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
        sendRfd(rfd: receivedForce)
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        //
    }
    
    func onRfdEmptyMillis(_ generator: TJLabsCommon.RFDGenerator, time: Double) {
        //
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
        calcJupiterResult()
    }
    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        JupiterCalcManager.currentVelocity = kmPh
    }
    func onMagNormSmoothingVarResult(_ generator: TJLabsCommon.UVDGenerator, value: Double) {
        //
    }
    
    // MARK: - TJLabsResourceManagerDelegate Methods
    func onBuildingLevelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, buildingLevelData: [String : [String]]) {
        //
    }
    
    func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.PathPixelData?) {
        //
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
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.EntranceRouteData?) {
        //
    }
    
    func onParamData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, data: TJLabsResource.ParameterData?) {
        //
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, key: String, data: TJLabsResource.GeofenceData?) {
        //
    }
    
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        //
    }
}
