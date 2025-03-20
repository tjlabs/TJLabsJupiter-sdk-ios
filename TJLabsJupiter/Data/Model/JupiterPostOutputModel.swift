
import Foundation

// MARK: - JupiterCalculatorResults
struct JupiterCalculatorResults {
    var fltResultList: [FineLocationTrackingOutput]
    var fltInput: FineLocationTrackingInput
    var inputTrajectoryInfo: [TrajectoryInfo]
    var inputSearchInfo: SearchInfo
}


// MARK: - FineLocationTracking
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

// MARK: - OnSpotRecognition
public struct OnSpotRecognitionOutput: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var linked_level_name: String
    public var spot_id: Int
    public var spot_distance: Double
    public var spot_range: [Int]
    public var spot_direction_down: [Int]
    public var spot_direction_up: [Int]

    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.linked_level_name = ""
        self.spot_id = 0
        self.spot_distance = 0
        self.spot_range = []
        self.spot_direction_down = []
        self.spot_direction_up = []
    }
}

// MARK: - RSSI Compensation
public struct RcInfo: Codable {
    let os_version: Int
    let normalization_scale: Double
}

public struct RcInfoOutputList: Codable {
    let rss_compensations: [RcInfo]
}

// MARK: - BlackList
public struct BlackListDevices: Codable {
    let android: [String: [String]]
    let iOS: IOSSupport
    let updatedTime: String
    
    enum CodingKeys: String, CodingKey {
        case android = "Android"
        case iOS = "iOS"
        case updatedTime = "updated_time"
    }
}

public struct IOSSupport: Codable {
    let apple: [String]
    enum CodingKeys: String, CodingKey {
        case apple = "Apple"
    }
}
