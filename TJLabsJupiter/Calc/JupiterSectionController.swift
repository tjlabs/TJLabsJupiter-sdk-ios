
import TJLabsCommon

class JupiterSectionController {
    private static var uvdSectionHeadings = [Double]()
    private static var uvdSectionLength: Double = 0
    static var sectionNumber: Int = 0
    
    static var anchorTailIndex: Int = 0
    
    private static var anchorSectioNumber: Int = 0
    private static var requestSectionNumber: Int = 0
    private static var sameSectionCount: Int = 2
    
    private static var requestSectionNumberInDRMode: Int = 0
    private static var sameSectionCountInDRMode: Int = 0
    
    static func extendedCheckIsNeedAnchorNodeUpdate(uvdLength: Double, curHeading: Double, preHeading: Double) -> Bool {
        var isNeedUpdate = false
        
        uvdSectionLength += uvdLength
        uvdSectionHeadings.append(TJLabsUtilFunctions.shared.compensateDegree(curHeading))
        
        var diffHeading = TJLabsUtilFunctions.shared.compensateDegree(curHeading - preHeading)
        if diffHeading > 270 { diffHeading = 360 - diffHeading }
        
        let circularStdAll = TJLabsUtilFunctions.shared.calculateCircularStd(for: uvdSectionHeadings)
        
        if diffHeading == 0 && circularStdAll <= JupiterSection.SECTION_STRAIGHT_ANGLE {
            if uvdSectionLength >= JupiterSection.REQUIRED_SECTION_STRAIGHT_LENGTH {
                if anchorSectioNumber != sectionNumber {
                    anchorSectioNumber = sectionNumber
                    isNeedUpdate = true
                }
            }
        } else {
            sectionNumber += 1
            uvdSectionLength = 0
            uvdSectionHeadings = []
        }
        
        return isNeedUpdate
    }
    
    static func checkIsNeedRequesttFltInDRMode() -> (Bool, Bool) {
        var isNeedRequest = false
        var isSectionChanged = false
        
        if uvdSectionLength >= JupiterSection.REQUIRED_SECTION_REQUEST_LENGTH_IN_DR {
            if requestSectionNumberInDRMode != sectionNumber {
                requestSectionNumberInDRMode = sectionNumber
                sameSectionCountInDRMode = 1
                isNeedRequest = false
                isSectionChanged = true
            } else {
                if uvdSectionLength >= JupiterSection.REQUIRED_SECTION_REQUEST_LENGTH_IN_DR*Double(sameSectionCount) {
                    sameSectionCount += 1
                    isNeedRequest = true
                }
            }
        }
        
        return (isNeedRequest, isSectionChanged)
    }
    
    static func setDRModeRequestSectionNumber() {
        requestSectionNumberInDRMode = sectionNumber
    }
    
    static func setInitialAnchorTailIndex(value: Int) {
        anchorTailIndex = value
    }
    
    static func getSectionLength() -> Double {
        return uvdSectionLength
    }
}
