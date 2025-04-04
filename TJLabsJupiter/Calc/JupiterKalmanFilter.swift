
import TJLabsCommon

class JupiterKalmanFilter {
    static var kalmanP: Double = 1
    static var kalmanQ: Double = 0.3
    static var kalmanR: Double = 0.5
    static var kalmanK: Double = 1
    
    static var headingKalmanP: Double = 0.5
    static var headingKalmanQ: Double = 0.5
    static var headingKalmanR: Double = 1
    static var headingKalmanK: Double = 1
    
    static var pastKalmanP: Double = 1
    static var pastKalmanQ: Double = 0.3
    static var pastKalmanR: Double = 0.5
    static var pastKalmanK: Double = 1
    
    static var pastHeadingKalmanP: Double = 0.5
    static var pastHeadingKalmanQ: Double = 0.5
    static var pastHeadingKalmanR: Double = 1
    static var pastHeadingKalmanK: Double = 1
    
    static var tuResult = FineLocationTrackingOutput()
    
    static func updateTuResult(result: FineLocationTrackingOutput) {
        self.tuResult = result
    }
    
    static func timeUpdate(uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput {
//        print("(CheckCurrentResult) : uvd = \(uvd)")
//        print("(CheckCurrentResult) : pastUvd = \(pastUvd)")
        
        let length = uvd.length
        let diffHeading = uvd.heading - pastUvd.heading
        let updatedHeading = TJLabsUtilFunctions.shared.compensateDegree(tuResult.absolute_heading + diffHeading)
        let updatedHeadingRadian = TJLabsUtilFunctions.shared.degree2radian(degree: updatedHeading)
        let dx = length*cos(updatedHeadingRadian)
        let dy = length*sin(updatedHeadingRadian)
        
        tuResult.x += dx
        tuResult.y += dy
        tuResult.absolute_heading = updatedHeading
        
        return tuResult
    }
    
    static  func pdrTimeUpdate(region: String, sectorId: Int, uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput {
        return FineLocationTrackingOutput()
    }
    
    static func drTimeUpdate(region: String, sectorId: Int, uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput {
        var nextTuResult = timeUpdate(uvd: uvd, pastUvd: pastUvd)
        let paddingValues = JupiterMode.PADDING_VALUES_DR
        
        let unitDRInfoBuffer = JupiterStackManager.unitDRInfoBuffer
        let drBufferStraightResults = JupiterStackManager.isDrBufferStraightCircularStd(uvdBuffer: unitDRInfoBuffer, numIndex: JupiterMode.DR_HEADING_CORR_NUM_IDX, condition: 10)
        let isDrStraight = nextTuResult.level_name == "B0" ? false : drBufferStraightResults.0
        
        let pmResults = JupiterPathMatchingCalculator.shared.pathMatching(region: region, sectorId: sectorId, building: nextTuResult.building_name, level: nextTuResult.level_name, x: nextTuResult.x, y: nextTuResult.y, heading: nextTuResult.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: paddingValues)
        
        let isPmSuccess = pmResults.0
        let pmXyhs: xyhs = pmResults.1
        nextTuResult.absolute_heading = TJLabsUtilFunctions.shared.compensateDegree(nextTuResult.absolute_heading)
        
        if isPmSuccess {
            nextTuResult.x = pmXyhs.x
            nextTuResult.y = pmXyhs.y
            if isDrStraight { nextTuResult.absolute_heading = TJLabsUtilFunctions.shared.compensateDegree(pmXyhs.heading) }
        } else {
            let pmResultsWithoutHeading = JupiterPathMatchingCalculator.shared.pathMatching(region: region, sectorId: sectorId, building: nextTuResult.building_name, level: nextTuResult.level_name, x: nextTuResult.x, y: nextTuResult.y, heading: nextTuResult.absolute_heading, headingRange: JupiterMode.HEADING_RANGE, isUseHeading: false, mode: .MODE_VEHICLE, paddingValues: paddingValues)
            nextTuResult.x = pmResultsWithoutHeading.1.x*0.2 + nextTuResult.x*0.8
            nextTuResult.y = pmResultsWithoutHeading.1.y*0.2 + nextTuResult.y*0.8
        }
        updateTuResult(result: nextTuResult)
        
        kalmanP += kalmanQ
        headingKalmanP += headingKalmanQ
        
        return nextTuResult
    }
}
