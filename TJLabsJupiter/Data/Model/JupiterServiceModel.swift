
import Foundation
import TJLabsCommon

public enum JupiterRegion: String {
    case KOREA = "KOREA"
    case US_EAST = "US_EAST"
    case CANADA = "CANADA"
}

struct xyhs {
    var x: Double = 0
    var y: Double = 0
    var heading: Double = 0
    var scale: Double = 0
}

// MARK: - TrajectoryInfo
struct TrajectoryInfo {
    var uvd: UserVelocity
    var jupiterResult: FineLocationTrackingOutput
    var serverResult: FineLocationTrackingOutput
}

struct SearchInfo {
    var searchRange: [Int] = []
    var searchDirection: [Int] = []
    var tailIndex: Int = 1
}

// MARK: - Node
struct NodeCandidateInfo {
    var isPhaseBreak: Bool = false
    var nodeCandidatesInfo: [PassedNodeInfo] = []
}

struct PassedNodeInfo {
    var nodeNumber: Int
    var nodeCoord: [Double]
    var nodeHeadings: [Double]
    var matchedIndex: Int
    var userHeading: Double
}

// MARK: - Info
struct DRModeRequestInfo {
    var trajectoryInfo: [TrajectoryInfo]
    var stableInfo: StableInfo
    var nodeCandidatesInfo: NodeCandidateInfo
    var prevNodeInfo: PassedNodeInfo
}

struct StableInfo {
    var tail_index: Int
    var head_section_number: Int
    var node_number_list: [Int]
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
