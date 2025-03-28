
import TJLabsCommon

class JupiterDataBatchSender {
    private static var inputReceivedForceArray = [ReceivedForce]()
    private static var inputUserVelocityArray = [UserVelocity]()
    private static var inputUserMaskArray = [UserMask]()
    
    static var sendRfdLength = 2
    static var sendUvdLength = 4
    static var sendUserMaskLength = 4
    
    static func sendRfd(rfd: ReceivedForce) {
        let rfdURL = JupiterNetworkConstants.getRecRfdURL()
        inputReceivedForceArray.append(rfd)
        if inputReceivedForceArray.count >= sendRfdLength {
            JupiterNetworkManager.shared.postReceivedForce(url: rfdURL, input: inputReceivedForceArray) { [self] statusCode, returnedString, inputRfd in
//                print("(POST) RFD : statusCode = \(statusCode)")
            }
            inputReceivedForceArray.removeAll()
        }
    }
    
    static func sendUvd(uvd: UserVelocity) {
        let uvdURL = JupiterNetworkConstants.getRecUvdURL()
        inputUserVelocityArray.append(uvd)
        if inputUserVelocityArray.count >= sendUvdLength {
            JupiterNetworkManager.shared.postUserVelocity(url: uvdURL, input: inputUserVelocityArray) { [self] statusCode, returnedString, inputUvd in
//                print("(POST) UVD : statusCode = \(statusCode)")
            }
            inputUserVelocityArray.removeAll()
        }
    }
    
    static func sendUserMask(userMask: UserMask) {
        let umURL = JupiterNetworkConstants.getRecUserMaskURL()
        inputUserMaskArray.append(userMask)
        if inputUserMaskArray.count >= sendUserMaskLength {
            JupiterNetworkManager.shared.postUserMask(url: umURL, input: inputUserMaskArray) { [self] statusCode, returnedString, inputUserMask in
//                print("(POST) UVD : statusCode = \(statusCode)")
            }
            inputUserMaskArray.removeAll()
        }
    }
}
