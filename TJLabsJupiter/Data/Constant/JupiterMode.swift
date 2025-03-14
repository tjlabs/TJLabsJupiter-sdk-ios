
class JupiterMode {
    static let MODE_DR = "dr"
    static let MODE_PDR = "pdr"
    static let MODE_AUTO = "auto"
    
    static var USER_TRAJECTORY_LENGTH: Double = 60
    static var USER_TRAJECTORY_LENGTH_DR: Double = 60
    static var USER_TRAJECTORY_LENGTH_PDR: Double = 20
    
    static var RQ_IDX: Int = 10
    static let RQ_IDX_PDR: Int = 4
    static let RQ_IDX_DR: Int = 10
    static var UVD_INPUT_NUM: Int = 3
    static var VALUE_INPUT_NUM: Int = 5
    static var INIT_INPUT_NUM: Int = 3
    static var INDEX_THRESHOLD: Int = 11
    static let UVD_BUFFER_SIZE: Int = 10
    
    static var PADDING_VALUE: Double = 15
    static var PADDING_VALUE_SMALL: Double = 10
    static var PADDING_VALUE_LARGE: Double =  20
    static var PADDING_VALUES: [Double] = Array(repeating: PADDING_VALUE, count: 4)
    static let DEFAULT_HEADINGS: [Double] = [0, 90, 180, 270]
    
    static func updateParam(mode: String, phase: Int) {
        if mode == MODE_PDR {
            setPDRParam(phase: phase)
        } else if mode == MODE_DR {
            setDRParam(phase: phase)
        }
    }
    
    static func setPDRParam(phase: Int) {
        RQ_IDX = RQ_IDX_PDR
        USER_TRAJECTORY_LENGTH = USER_TRAJECTORY_LENGTH_PDR
        INIT_INPUT_NUM = 4
        VALUE_INPUT_NUM = 6
        PADDING_VALUE = PADDING_VALUE_SMALL
        PADDING_VALUES = Array(repeating: PADDING_VALUE, count: 4)
        if (phase >= JupiterPhase.PHASE_4) {
            UVD_INPUT_NUM = VALUE_INPUT_NUM
            INDEX_THRESHOLD = 21
        } else {
            UVD_INPUT_NUM = INIT_INPUT_NUM
            INDEX_THRESHOLD = 11
        }
    }
    
    static func setDRParam(phase: Int) {
        RQ_IDX = RQ_IDX_DR
        USER_TRAJECTORY_LENGTH = USER_TRAJECTORY_LENGTH_DR
        INIT_INPUT_NUM = 5
        VALUE_INPUT_NUM = UVD_BUFFER_SIZE
        PADDING_VALUE = PADDING_VALUE_LARGE
        PADDING_VALUES = Array(repeating: PADDING_VALUE, count: 4)
        if (phase >= JupiterPhase.PHASE_4) {
            UVD_INPUT_NUM = VALUE_INPUT_NUM
            INDEX_THRESHOLD = (UVD_INPUT_NUM * 2) + 1
        } else {
            UVD_INPUT_NUM = INIT_INPUT_NUM
            INDEX_THRESHOLD = UVD_INPUT_NUM + 1
        }
    }
}

