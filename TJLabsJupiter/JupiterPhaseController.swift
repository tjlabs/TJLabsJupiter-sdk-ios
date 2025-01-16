
import Foundation
import TJLabsCommon

class JupiterCalculator: UVDGeneratorDelegate {
    
    private static var phase = 1
        
    static func getPhase() -> Int {
        return phase
    }
    
    func onUvdResult(_ generator: TJLabsCommon.UVDGenerator, userVelocity: TJLabsCommon.UserVelocity) {
        // TO-DO
    }
    
    func onPressureResult(_ generator: TJLabsCommon.UVDGenerator, hPa: Double) {
        // TO-DO
    }
    
    func onVelocityResult(_ generator: TJLabsCommon.UVDGenerator, kmPh: Double) {
        // TO-DO
    }
    
    func onUvdPauseMillis(_ generator: TJLabsCommon.UVDGenerator, time: Double) {
        // TO-DO
    }
    
    func onUvdError(_ generator: TJLabsCommon.UVDGenerator, error: String) {
        // TO-DO
    }
}
