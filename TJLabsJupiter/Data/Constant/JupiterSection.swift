
class JupiterSection {
    static let SECTION_STRAIGHT_ANGLE: Double = 10
    static let REQUIRED_SECTION_STRAIGHT_LENGTH: Double = 6
    static let REQUIRED_SECTION_REQUEST_LENGTH: Double = 25
    static let REQUIRED_SECTION_REQUEST_LENGTH_IN_DR: Double = 10
    
    static let SAME_COORD_THRESHOLD: Int = 4
    static let STRAIGHT_SAME_COORD_THRESHOLD: Int = 6
    static let MAGNETIC_NORTH_THRESHOLD = 100
    static let MAGNETIC_COMPENSATION_DEGREE = 180 // LG : 180 Tips : -20
    
    static let PIXEL_LENGTH_TO_FIND_NODE: Double = 20

    static let DR_INFO_BUFFER_SIZE: Int = 60 // 30
    static let DR_BUFFER_SIZE_FOR_STRAIGHT: Int = 10 // COEX 12 // DS 6 //default 10 // tips : 4
    static let DR_BUFFER_SIZE_FOR_HEAD_STRAIGHT: Int = 3
    static let DR_HEADING_CORR_NUM_IDX: Int = 10
}
