
import Foundation
import TJLabsCommon
import UIKit

public class JupiterManager: RFDGeneratorDelegate, UVDGeneratorDelegate {
    public static let sdkVersion: String = "0.0.1"
    
    var deviceModel: String
    var deviceIdentifier: String
    var deviceOsVersion: Int
    
    public weak var delegate: JupiterManagerDelegate?
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    private var isStartService = false
    private let sharedRfdCallback = SharedRFDGeneratorDelegate()
    private let sharedUvdCallback = SharedUVDGeneratorDelegate()
    private var pressure: Float = 0.0
    private let jupiterPhaseController = JupiterPhaseController()
    private var inputReceivedForce: [ReceivedForce] = []
    private var inputUserVelocity: [UserVelocity] = []
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
    init() {
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
    }
    
    // MARK: - Start & Stop Jupiter Service
    func startJupiter(id: String, region: JupiterRegion = .KOREA) {
        let (isNetworkAvailable, msgCheckNetworkAvailable) = JupiterNetworkManager.shared.isConnectedToInternet()
        let (isIdAvailable, msgCheckIdAvailable) = checkIdIsAvailable(id: id)
        
        if !isNetworkAvailable {
            delegate?.onJupiterError(0, msgCheckNetworkAvailable)
            return
        }
        
        if !isIdAvailable {
            delegate?.onJupiterError(0, msgCheckIdAvailable)
            return
        }
        
        if isStartService {
            delegate?.onJupiterError(0, "The service is already starting.")
            return
        }
        
        let loginInput = LoginInput(user_id: id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: JupiterManager.sdkVersion)
        let tasks: [(DispatchGroup) -> Void] = [
            { group in
                group.enter()
                let loginURL = JupiterNetworkConstants.getUserLoginURL()
                JupiterNetworkManager.shared.postUserLogin(url: loginURL, input: loginInput) { success, msg in
                    if success != 200 {
                        self.delegate?.onJupiterError(success, msg)
                    }
                    group.leave()
                }
            }
            // Add Another Group
//            ,{ group in
//                group.enter()
//                let loginURL = JupiterNetworkConstants.getUserLoginURL()
//                JupiterNetworkManager.shared.postUserLogin(url: loginURL, input: loginInput) { success, msg in
//                    if success != 200 {
//                        self.delegate?.onJupiterError(success, msg)
//                    }
//                    group.leave()
//                }
//            }
        ]
        
        performTasksWithCounter(tasks: tasks, onComplete: {
            self.isStartService = true
            JupiterNetworkConstants.setServerURL(region: region)
            self.startGenerator(id: id)
        }, onError: { msg in
            self.delegate?.onJupiterError(0, msg)
        })
    }

    private func performTasksWithCounter(tasks: [(DispatchGroup) -> Void],
                                         onComplete: @escaping () -> Void,
                                         onError: @escaping (String) -> Void) {
        let dispatchGroup = DispatchGroup()
        var isErrorOccurred = false
        
        for task in tasks {
            task(dispatchGroup)
        }
        
        dispatchGroup.notify(queue: .main) {
            if !isErrorOccurred {
                onComplete()
            }
        }
    }

    
    func stopJupiter() {
        stopGenerator()
    }
    
    // MARK: - Set REC length
    func setSendRfdLength(_ length: Int = 2) {
        sendRfdLength = length
    }
    
    func setSendUvdLength(_ length: Int = 4) {
        sendUvdLength = length
    }
    
    // MARK: - ID Validation
    private func checkIdIsAvailable(id: String) -> (Bool, String) {
        if id.isEmpty || id.contains(" ") {
            let msg = "(Olympus) Error: User ID (input = \(id)) cannot be empty or contain spaces."
            return (false, msg)
        }
        return (true, "")
    }
    
    // MARK: - Start & Stop Generation
    private func startGenerator(id: String) {
        rfdGenerator = RFDGenerator(userId: id)
        uvdGenerator = UVDGenerator(userId: id)
        
        rfdGenerator?.generateRfd()
        rfdGenerator?.delegate = self
        
        uvdGenerator?.generateUvd()
        uvdGenerator?.delegate = self
        
        sharedUvdCallback.addListener(jupiterPhaseController)
    }
    
    private func stopGenerator() {
        if isStartService {
            rfdGenerator?.stopRfdGeneration()
            uvdGenerator?.stopUvdGeneration()
            isStartService = false
        }
    }
    
    // MARK: - Send Data to REC
    private func sendRfd(rfd: ReceivedForce) {
        let rfdURL = JupiterNetworkConstants.getRecRfdURL()
        inputReceivedForce.append(rfd)
        if inputReceivedForce.count >= sendRfdLength {
            JupiterNetworkManager.shared.postReceivedForce(url: rfdURL, input: inputReceivedForce) { _, _, _ in }
            inputReceivedForce.removeAll()
        }
    }
    
    private func sendUvd(uvd: UserVelocity) {
        let uvdURL = JupiterNetworkConstants.getRecUvdURL()
        inputUserVelocity.append(uvd)
        if inputUserVelocity.count >= sendUvdLength {
            JupiterNetworkManager.shared.postUserVelocity(url: uvdURL, input: inputUserVelocity) { _, _, _ in }
            inputUserVelocity.removeAll()
        }
    }
    
    // MARK: - Delegates
    public func onRfdError(_ generator: RFDGenerator, code: Int, msg: String) {}
    public func onRfdResult(_ generator: RFDGenerator, receivedForce: ReceivedForce) {
        sendRfd(rfd: receivedForce)
        sharedRfdCallback.onRfdResult(generator, receivedForce: receivedForce)
    }
    
    public func onPressureResult(_ generator: UVDGenerator, hPa: Double) {
        pressure = Float(hPa)
    }
    public func onUvdResult(_ generator: UVDGenerator, userVelocity: UserVelocity) {
        sharedUvdCallback.onUvdResult(generator, userVelocity: userVelocity)
        sendUvd(uvd: userVelocity)
    }
    public func onUvdError(_ generator: UVDGenerator, error: String) {}
    public func onUvdPauseMillis(_ generator: UVDGenerator, time: Double) {}
    public func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {}
}
