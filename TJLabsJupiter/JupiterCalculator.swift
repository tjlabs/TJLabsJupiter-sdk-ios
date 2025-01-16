import Foundation
import TJLabsCommon

class JupiterCalculator: UVDGeneratorDelegate {
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
    static var calTime: Double = 0.0
    static var currentUvd = UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    static var bleOnlyPosition: Bool = false
    static var isIndoor: Bool = false
    static var validity: Bool = false
    static var validityFlag: Int = 0
    static var currentVelocity: Double = 0.0
    static var currentUserMode: UserMode = .MODE_PEDESTRIAN
    
    // MARK: - Static Methods
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
            search_range: [0],
            search_direction_list: [0],
            normalization_scale: 1.0,
            device_min_rss: -99,
            sc_compensation_list: [1.0],
            tail_index: 0,
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

    // MARK: - Initialization
    init(id: String, sectorId: Int) {
        JupiterCalculator.id = id
        JupiterCalculator.sectorId = sectorId
    }

    // MARK: - Calculation Methods
    private func calcJupiterResult() {
        switch JupiterCalculator.phase {
        case 1:
            calculatePhase1()
        case 2:
            // TODO: Implement Phase 2
            break
        case 3:
            // TODO: Implement Phase 3
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
    }

    private func calculatePhase1() {
        if JupiterCalculator.currentUvd.index % JupiterCalculator.fltRequestIndex == 0 {
            let phase1Input = JupiterCalculator.getLatestFineLocationTrackingInput()
            let fltInput = FLT(fltInput: phase1Input, trajInfoList: [], searchInfo: SearchInfo())
            JupiterNetworkManager.shared.postFLT(url: JupiterNetworkConstants.getCalcFltURL(), input: fltInput, completion: { [self] statusCode, returnedString, input in
                if statusCode == 200 {
                    let decodedResult = decodeFineLocationTrackingOutputList(jsonString: returnedString)
                    let result = decodedResult.1.flt_outputs
                    let fltResult = result.isEmpty ? FineLocationTrackingOutput() : result[0]
                    if decodedResult.0 && fltResult.x != 0 || fltResult.y != 0 {
                        JupiterCalculator.buildingName = fltResult.building_name
                        JupiterCalculator.levelName = fltResult.level_name
                        JupiterCalculator.scc = fltResult.scc
                        JupiterCalculator.x = fltResult.x
                        JupiterCalculator.y = fltResult.y
                        JupiterCalculator.absoluteHeading = fltResult.absolute_heading
                        JupiterCalculator.calTime = fltResult.calculated_time
                        
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
        JupiterCalculator.currentUserMode = mode
        JupiterCalculator.currentUvd = userVelocity
        calcJupiterResult()
    }

    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        JupiterCalculator.currentVelocity = kmPh
    }
}
