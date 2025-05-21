
class JupiterStateManager {
    static var isGetFirstResponse = false
    static var isReadyPpResource = false
    static var isReadyEntranceResource = false
    static var isPhaseBreak = false
    static var isIndoor: Bool = false
    static var isRouteTrack : Bool = false
    static var validity: Bool = false
    static var validity_flag: Int = 0
    static var isDRMode = false
    static var isVenus = false
    static var isPossibleHeadingCorrection: Bool = false
    static var isAmbiguous = false
    static var isAmbiguousInDRMode = false
    static var isInRecoveryProcess = false
    static var stableModeInitFlag = true
    static var isDRModeRqInfoSaved = false
    static var isSleepMode = false
    static var isInMapEnd = false
    static var isBecomeForeground = false
    static var networkStatus = true
}
