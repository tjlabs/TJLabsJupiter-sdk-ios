
import TJLabsCommon

class JupiterPhaseController {
    
    // MARK: - Control Phase
    static func controlPhase(inputPhase: Int, curResult: FineLocationTrackingOutput, preResult: FineLocationTrackingOutput, drBuffer: [UserVelocity], mode: UserMode) -> Int {
        var phase: Int = 0
        let phaseBreakSCC = mode == .MODE_PEDESTRIAN ? JupiterPhase.PHASE_BREAK_SCC_PDR : JupiterPhase.PHASE_BREAK_SCC_DR
        
        switch (inputPhase) {
        case 0, 1:
            phase = self.phase1control(serverResult: curResult, mode: mode)
        case 3:
            if (curResult.scc < phaseBreakSCC) {
                phase = 1
            } else {
                checkScResultConnectionForStable(phase: phase)
            }
        case 5:
            phase = self.phaseControlInStable(serverResult: curResult, mode: mode, inputPhase: 6)
        case 6:
            phase = self.phaseControlInStable(serverResult: curResult, mode: mode, inputPhase: 6)
        default:
            phase = 0
        }
        
        return phase
    }
    
    static func phase1control(serverResult: FineLocationTrackingOutput, mode: UserMode) -> Int {
        var phase: Int = 0
        
        let building_name = serverResult.building_name
        let level_name = serverResult.level_name
        let scc = serverResult.scc
        
        if (building_name != "" && level_name != "") {
            if (scc >= JupiterPhase.PHASE_BECOME3_SCC) {
                phase = 3
            } else {
                phase = 1
            }
        }
        
        return phase
    }
    
    static func checkScResultConnectionForStable(phase: Int) -> Int {
        return phase
    }
    
    static func phaseControlInStable(serverResult: FineLocationTrackingOutput, mode: UserMode, inputPhase: Int) -> Int {
        var phase: Int = 1
        return phase
    }
}
