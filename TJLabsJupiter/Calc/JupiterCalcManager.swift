import Foundation
import TJLabsCommon

class JupiterCalcManager: UVDGeneratorDelegate {
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
    init(id: String, sectorId: Int) {
        JupiterCalcManager.id = id
        JupiterCalcManager.sectorId = sectorId
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
        JupiterCalcManager.currentUserMode = mode
        JupiterCalcManager.currentUvd = userVelocity
        calcJupiterResult()
    }

    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        JupiterCalcManager.currentVelocity = kmPh
    }
}
