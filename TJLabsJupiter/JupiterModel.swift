
import Foundation

public struct LoginInput: Codable {
    public var user_id: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

public enum JupiterRegion {
    case KOREA, US, CANADA
}

// Fine Location Tracking
public struct FineLocationTrackingResult: Codable {
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

public protocol JupiterManagerDelegate: AnyObject {
    func onJupiterResult(_ result: FineLocationTrackingResult)
    func onJupiterError(_ code: Int, _ msg: String)
}
