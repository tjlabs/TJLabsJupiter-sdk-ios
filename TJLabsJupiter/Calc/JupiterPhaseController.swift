
import TJLabsCommon

class JupiterPhaseController {
    
    // MARK: - Control Phase
    static func controlPhase(inputPhase: Int, curResult: FineLocationTrackingOutput, preResult: FineLocationTrackingOutput, trajectoryBuffer: [TrajectoryInfo], drBuffer: [UserVelocity], mode: UserMode) -> Int {
        var phase: Int = 0
        let phaseBreakSCC = mode == .MODE_PEDESTRIAN ? JupiterPhase.PHASE_BREAK_SCC_PDR : JupiterPhase.PHASE_BREAK_SCC_DR
        
        switch (inputPhase) {
        case 0, 1:
            phase = self.phase1control(serverResult: curResult, mode: mode)
        case 3:
            if (curResult.scc < phaseBreakSCC) {
                phase = 1
            } else {
                let rqIndex = mode == .MODE_VEHICLE ? JupiterMode.RQ_IDX_DR : JupiterMode.RQ_IDX_PDR
                let hasMajorHeading = JupiterTrajectoryCalculator.checkHasMajorDirection(trajectoryBuffer: trajectoryBuffer)
                let updatedPhase = checkScResultConnectionForStable(inputPhase: inputPhase, curResult: curResult, preResult: preResult, drBuffer: drBuffer, hasMajorDirection: hasMajorHeading, INDEX_THRESHOLD: rqIndex, mode: mode)
                phase = updatedPhase
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
    
    static func checkScResultConnectionForStable(
        inputPhase: Int,
        curResult: FineLocationTrackingOutput,
        preResult: FineLocationTrackingOutput,
        drBuffer: [UserVelocity],
        hasMajorDirection: Bool,
        INDEX_THRESHOLD: Int,
        mode: UserMode
    ) -> Int {
        var phase = inputPhase
        let sccCondition: Double = 0.5
        var isPoolChannel = false
        let indexCondition = INDEX_THRESHOLD * 2

        let distanceCondition = mode == .MODE_VEHICLE ? 15.0 : 3.0
        let headingCondition = mode == .MODE_VEHICLE ? 30.0 : 5.0

        // Check Phase
        if preResult == FineLocationTrackingOutput() {
            return phase
        } else {
            if curResult.scc < sccCondition ||
                preResult.index == 0 ||
                curResult.index == 0 ||
                curResult.cumulative_length < JupiterPhase.STABLE_ENTER_LENGTH ||
                !hasMajorDirection {
                return phase
            } else {
                if inputPhase != 2 {
                    isPoolChannel = !curResult.channel_condition && !preResult.channel_condition
                }
                if isPoolChannel {
                    return phase
                } else {
                    if (curResult.index - preResult.index) > indexCondition || curResult.index <= preResult.index {
                        return phase
                    } else {
                        var drBufferStartIndex = 0
                        var drBufferEndIndex = 0
                        var headingCompensation: Double = 0.0

                        for i in drBuffer.indices {
                            if drBuffer[i].index == preResult.index {
                                drBufferStartIndex = i
                                headingCompensation = preResult.absolute_heading - drBuffer[i].heading
                            }
                            if drBuffer[i].index == curResult.index {
                                drBufferEndIndex = i
                            }
                        }

                        var propagatedXyh: [Double] = [
                            preResult.x,
                            preResult.y,
                            preResult.absolute_heading
                        ]

                        for i in drBufferStartIndex..<drBufferEndIndex {
                            let length = drBuffer[i].length
                            let heading = Double(drBuffer[i].heading + headingCompensation)
                            let dx = length * cos(heading * .pi / 180)
                            let dy = length * cos(heading * .pi / 180)

                            propagatedXyh[0] += dx
                            propagatedXyh[1] += dy
                        }

                        let dh = drBuffer[drBufferEndIndex].heading - drBuffer[drBufferStartIndex].heading
                        propagatedXyh[2] += dh
                        propagatedXyh[2] = TJLabsUtilFunctions.shared.compensateDegree(propagatedXyh[2])

                        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: curResult.level_name)
                        let paddingValues = mode == .MODE_VEHICLE ? JupiterMode.PADDING_VALUES_DR : JupiterMode.PADDING_VALUES_PDR
                        let pmResults = JupiterPathMatchingCalculator.shared.pathMatching(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, building: curResult.building_name, level: levelName, x: propagatedXyh[0], y: propagatedXyh[1], heading: propagatedXyh[2], headingRange: JupiterMode.HEADING_RANGE, isUseHeading: false, mode: mode, paddingValues: paddingValues)
                        let pathMatchingResult = pmResults.1
                        let diffX = abs(pathMatchingResult.x - curResult.x)
                        let diffY = abs(pathMatchingResult.y - curResult.y)
                        let currentResultHeading = TJLabsUtilFunctions.shared.compensateDegree(curResult.absolute_heading)
                        var diffH = abs(pathMatchingResult.heading - currentResultHeading)
                        if diffH > 270 {
                            diffH = 360 - diffH
                        }

                        let rendezvousDistance = sqrt(diffX * diffX + diffY * diffY)
                        if rendezvousDistance <= distanceCondition && diffH <= headingCondition {
                            phase = JupiterPhase.PHASE_6
                        }
                        return phase
                    }
                }
            }
        }
    }

    
    static func phaseControlInStable(serverResult: FineLocationTrackingOutput, mode: UserMode, inputPhase: Int) -> Int {
        var phase: Int = inputPhase
        let phaseBreakSCC = mode == .MODE_VEHICLE ? JupiterPhase.PHASE_BREAK_SCC_DR : JupiterPhase.PHASE_BREAK_SCC_PDR
        
        let scc = serverResult.scc
        
        if scc < phaseBreakSCC {
            phase = 1
        } else if serverResult.x == 0 && serverResult.y == 0 {
            phase = 1
        }
        
        return phase
    }
}
