
import TJLabsCommon

class JupiterMode {
    // LT : Less Than
    // GTE : Greater Than or Equal
    static var RQ_IDX_PDR: Int = 4
    static var RQ_IDX_DR: Int = 10

    static var USER_TRAJECTORY_LENGTH_DR: Double = 60
    static var USER_TRAJECTORY_LENGTH_PDR: Double = 20

    static var REQUIRED_LENGTH_FOR_MAJOR_HEADING: Double = 10
    
    static var UVD_INPUT_NUM_GTE_PHASE4_PDR: Int = 6
    static var INDEX_THRESHOLD_GTE_PDR = 21

    static var UVD_INPUT_NUM_LT_PHASE4_PDR: Int = 4
    static var INDEX_THRESHOLD_LT_PHASE4_PDR = 11

    static var UVD_INPUT_NUM_GTE_PHASE4_DR: Int = 10
    static var INDEX_THRESHOLD_GTE_DR = (UVD_INPUT_NUM_GTE_PHASE4_DR * 2) + 1 // 21

    static var UVD_INPUT_NUM_LT_PHASE4_DR: Int = 5
    static var INDEX_THRESHOLD_LT_PHASE4_DR = UVD_INPUT_NUM_LT_PHASE4_DR + 1 //6

    static var HEADING_RANGE: Double = 46
    static var DEFAULT_HEADINGS: [Double] = [0, 90, 180, 270]

    static var PADDING_VALUE_SMALL: Double = 10
    static var PADDING_VALUE_LARGE: Double = 20

    static var PADDING_VALUES_PDR: [Double] = Array(repeating: PADDING_VALUE_SMALL, count: 4)
    static var PADDING_VALUES_DR: [Double] = Array(repeating: PADDING_VALUE_LARGE, count: 4)
    
    static let DR_HEADING_CORR_NUM_IDX: Int = 10
    static let HEADING_UNCERTANTIY: Double = 2.0
}

