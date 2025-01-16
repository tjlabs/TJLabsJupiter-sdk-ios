
import Foundation
import TJLabsCommon

public struct LoginInput: Codable {
    public var user_id: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

public enum JupiterRegion {
    case KOREA, US, CANADA
}


// MARK: - FineLocationTracking
public struct TrajectoryInfo {
    public var index: Int = 0
    public var length: Double = 0
    public var heading: Double = 0
    public var velocity: Double = 0
    public var lookingFlag: Bool = false
    public var isIndexChanged: Bool = false
    public var numBleChannels: Int = 0
    public var scc: Double = 0
    public var userBuilding: String = ""
    public var userLevel: String = ""
    public var userX: Double = 0
    public var userY: Double = 0
    public var userHeading: Double = 0
    public var userPmSuccess: Bool = false
    public var userTuHeading: Double = 0
}

public enum TrajType {
    case DR_UNKNOWN,
         DR_IN_PHASE3,
         DR_ALL_STRAIGHT,
         DR_HEAD_STRAIGHT,
         DR_TAIL_STRAIGHT,
         DR_RQ_IN_PHASE2,
         DR_NO_RQ_IN_PHASE2,
         PDR_IN_PHASE3_HAS_MAJOR_DIR,
         PDR_IN_PHASE3_NO_MAJOR_DIR,
         PDR_IN_PHASE4_HAS_MAJOR_DIR,
         PDR_IN_PHASE4_NO_MAJOR_DIR,
         PDR_IN_PHASE4_ABNORMAL
}

public struct SearchInfo {
    public var searchRange: [Int] = []
    public var searchArea: [[Double]] = [[0, 0]]
    public var searchDirection: [Int] = [0, 90, 180, 270]
    public var tailIndex: Int = 1
    public var trajShape: [[Double]] = [[0, 0]]
    public var trajStartCoord: [Double] = [0, 0]
    public var trajType: TrajType = TrajType.DR_UNKNOWN
    public var trajLength: Double = 0
}

public struct FineLocationTrackingInput: Encodable {
    var user_id: String
    var mobile_time: Int
    var sector_id: Int
    var operating_system: String
    var building_name: String
    var level_name_list: [String]
    var phase: Int
    var search_range: [Int]
    var search_direction_list: [Int]
    var normalization_scale: Double
    var device_min_rss: Int
    var sc_compensation_list: [Double]
    var tail_index: Int
    var head_section_number: Int
    var node_number_list: [Int]
    var node_index: Int
    var retry: Bool
}

public struct FineLocationTrackingOutput: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var x: Double
    public var y: Double
    public var absolute_heading: Double
    public var phase: Int
    public var calculated_time: Double
    public var index: Int
    public var velocity: Double
    public var mode: String
    public var ble_only_position: Bool
    public var isIndoor: Bool
    public var validity: Bool
    public var validity_flag: Int
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.x = 0
        self.y = 0
        self.absolute_heading = 0
        self.phase = 0
        self.calculated_time = 0
        self.index = 0
        self.velocity = 0
        self.mode = ""
        self.ble_only_position = false
        self.isIndoor = false
        self.validity = false
        self.validity_flag = 0
    }
}

struct FLT {
    var fltInput: FineLocationTrackingInput
    var trajInfoList: [TrajectoryInfo]
    var searchInfo: SearchInfo
}

// MARK: - JupiterResult
public struct JupiterResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var x: Double
    public var y: Double
    public var absolute_heading: Double
    public var phase: Int
    public var calculated_time: Double
    public var index: Int
    public var velocity: Double
    public var mode: UserMode
    public var ble_only_position: Bool
    public var isIndoor: Bool
    public var validity: Bool
    public var validity_flag: Int
    
//    public init() {
//        self.mobile_time = 0
//        self.building_name = ""
//        self.level_name = ""
//        self.scc = 0
//        self.x = 0
//        self.y = 0
//        self.absolute_heading = 0
//        self.phase = 0
//        self.calculated_time = 0
//        self.index = 0
//        self.velocity = 0
//        self.mode = .MODE_PEDESTRIAN
//        self.ble_only_position = false
//        self.isIndoor = false
//        self.validity = false
//        self.validity_flag = 0
//    }
}

public protocol JupiterManagerDelegate: AnyObject {
    func onJupiterResult(_ result: JupiterResult)
    func onJupiterError(_ code: Int, _ msg: String)
}
