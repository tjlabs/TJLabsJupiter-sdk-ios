
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

public struct SearchInfo {
    public var searchRange: [Int] = []
    public var searchDirection: [Int] = [0, 90, 180, 270]
    public var tailIndex: Int = 1
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
    public var calculated_time: Double
    public var index: Int
    public var sc_compensation: Double
    public var node_number: Int
    public var search_direction: Int
    public var cumulative_length: Double
    public var channel_condition: Bool
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.x = 0
        self.y = 0
        self.absolute_heading = 0
        self.calculated_time = 0
        self.index = 0
        self.sc_compensation = 0
        self.node_number = 0
        self.search_direction = 0
        self.cumulative_length = 0
        self.channel_condition = false
    }
}

public struct FineLocationTrackingOutputList: Codable {
    public var flt_outputs: [FineLocationTrackingOutput]
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
    func onJupiterSuccess(_ isSuccess: Bool)
    func onJupiterError(_ code: Int, _ msg: String)
    func onJupiterResult(_ result: JupiterResult)
}
