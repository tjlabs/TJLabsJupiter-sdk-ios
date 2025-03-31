
import Foundation

public struct LoginInput: Codable {
    public var user_id: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

// MARK: - FineLocationTracking
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

struct FLT {
    var fltInput: FineLocationTrackingInput
    var trajInfoList: [TrajectoryInfo]
    var searchInfo: SearchInfo
}

struct StableFLT {
    var fltInput: FineLocationTrackingInput
    var trajInfoList: [TrajectoryInfo]
    var nodeCandidateInfo: NodeCandidateInfo
}

// MARK: - OnSpotRecognition
struct OnSpotRecognitionInput: Encodable {
    var operating_system: String
    var user_id: String
    var mobile_time: Int
    var normalization_scale: Double
    var device_min_rss: Int
    var standard_min_rss: Int
}

// MARK: - MobileResult & Report
public struct MobileResult: Encodable {
    public var user_id: String
    public var mobile_time: Int
    public var sector_id: Int
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
    public var ble_only_position: Bool
    public var normalization_scale: Double
    public var device_min_rss: Int
    public var sc_compensation: Double
    public var is_indoor: Bool
}

public struct MobileReport: Encodable {
    public var user_id: String
    public var mobile_time: Int
    public var report: Int
}

// MARK: - RSSI Compensation
struct RcDeviceOsInput: Codable {
    let sector_id: Int
    let device_model: String
    let os_version: Int
}

struct RcDeviceInput: Codable {
    let sector_id: Int
    let device_model: String
}

struct RcInfoSave: Codable {
    let sector_id: Int
    let device_model: String
    let os_version: Int
    let normalization_scale: Double
}

// MARK: - UserMask
struct UserMask: Encodable {
    let user_id: String
    let mobile_time: Int
    let section_number: Int
    let index: Int
    let x: Int
    let y: Int
    let absolute_heading: Double
}
