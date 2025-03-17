
import Foundation
import TJLabsCommon
import UIKit

public class JupiterManager {
    public static let sdkVersion: String = "0.0.1"
    
    var id: String = ""
    var sectorId: Int = 0
    var region: JupiterRegion = .KOREA
    var deviceModel: String
    var deviceIdentifier: String
    var deviceOsVersion: Int
    
    public weak var delegate: JupiterManagerDelegate?
    
    private var isStartService = false
    private var jupiterCalcMananger: JupiterCalcManager?
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
    // MARK: - JupiterResult Timer
    var outputTimer: DispatchSourceTimer?
    
    public init(id: String) {
        self.id = id
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
    }

    // MARK: - Start & Stop Jupiter Service
    public func startJupiter(region: String = JupiterRegion.KOREA.rawValue, sectorId: Int) {
        let (isNetworkAvailable, msgCheckNetworkAvailable) = JupiterNetworkManager.shared.isConnectedToInternet()
        let (isIdAvailable, msgCheckIdAvailable) = checkIdIsAvailable(id: id)
        
        if !isNetworkAvailable {
            delegate?.onJupiterError(0, msgCheckNetworkAvailable)
            delegate?.onJupiterSuccess(false)
            return
        }
        
        if !isIdAvailable {
            delegate?.onJupiterError(0, msgCheckIdAvailable)
            delegate?.onJupiterSuccess(false)
            return
        }
        
        if isStartService {
            delegate?.onJupiterError(0, "The service is already starting.")
            delegate?.onJupiterSuccess(false)
            return
        }
        
        let loginInput = LoginInput(user_id: self.id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: JupiterManager.sdkVersion)
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
            self.jupiterCalcMananger = .init(region: region, id: self.id, sectorId: sectorId)
            self.jupiterCalcMananger?.setSendRfdLength(self.sendRfdLength)
            self.jupiterCalcMananger?.setSendUvdLength(self.sendUvdLength)
            self.startTimer()
            self.delegate?.onJupiterSuccess(true)
        }, onError: { msg in
            self.delegate?.onJupiterError(0, msg)
            self.delegate?.onJupiterSuccess(false)
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

    public func stopJupiter() {
        stopTimer()
        stopGenerator()
    }
    
    private func startGenerator(completion: @escaping (Bool, String) -> Void) {
        jupiterCalcMananger?.startGenerator(completion: { isSuccess, message in
            completion(isSuccess, message)
        })
    }
    
    private func stopGenerator() {
        if isStartService {
            jupiterCalcMananger?.stopGenerator()
            isStartService = false
        }
    }
    
    
    // MARK: - ID Validation
    private func checkIdIsAvailable(id: String) -> (Bool, String) {
        if id.isEmpty || id.contains(" ") {
            let msg = TJLabsUtilFunctions.shared.getLocalTimeString() + " , (TJLabsJupiter) Error: User ID (input = \(id)) cannot be empty or contain spaces."
            return (false, msg)
        }
        return (true, "")
    }
    
    // MARK: - Jupiter Timer
    func startTimer() {
        if (self.outputTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".outputTimer")
            self.outputTimer = DispatchSource.makeTimerSource(queue: queue)
            self.outputTimer!.schedule(deadline: .now(), repeating: JupiterTime.OUTPUT_INTEVAL)
            self.outputTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.outputTimerUpdate()
            }
            self.outputTimer!.resume()
        }
    }
    
    func stopTimer() {
        self.outputTimer?.cancel()
        self.outputTimer = nil
    }
    
    func outputTimerUpdate() {
        if JupiterCalcManager.isPossibleReturnJupiterResult() {
            let jupiterResult = JupiterCalcManager.getJupiterResult()
            delegate?.onJupiterResult(jupiterResult)
        }
    }
    
    // MARK: - Blacklist Check
    public func checkServiceAvailableDevice(completion: @escaping (Bool) -> Void) {
        JupiterNetworkManager.shared.getBlackList(url: JupiterNetworkConstants.getClientBlacklistURL()) { [weak self] statusCode, returnedString in
            guard let self = self else { return }
            
            let (cachedServiceAvailable, cachedUpdatedTime) = loadBlacklistInfo()
            var isServiceAvailable = cachedServiceAvailable
            var blacklistUpdatedTime = cachedUpdatedTime
            
            if statusCode == 200, let blackListDevices = decodeBlackListDevices(from: returnedString) {
                let updatedTime = blackListDevices.updatedTime
                let isBlacklistUpdated = cachedUpdatedTime.isEmpty || cachedUpdatedTime != updatedTime
                
                if isBlacklistUpdated {
                    logBlacklistDetails(blackListDevices)
                    isServiceAvailable = !blackListDevices.iOS.apple.contains { $0.contains(self.deviceIdentifier) }
                }
                blacklistUpdatedTime = updatedTime
            }
            
            saveBlacklistInfo(isServiceAvailable: isServiceAvailable, updatedTime: blacklistUpdatedTime)
            completion(isServiceAvailable)
        }
    }

    private func loadBlacklistInfo() -> (Bool, String) {
        let isServiceAvailable = UserDefaults.standard.bool(forKey: "JupiterIsServiceAvailable")
        let updatedTime = UserDefaults.standard.string(forKey: "JupiterBlacklistUpdatedTime") ?? ""
        return (isServiceAvailable, updatedTime)
    }

    private func saveBlacklistInfo(isServiceAvailable: Bool, updatedTime: String) {
        UserDefaults.standard.set(isServiceAvailable, forKey: "JupiterIsServiceAvailable")
        UserDefaults.standard.set(updatedTime, forKey: "JupiterBlacklistUpdatedTime")
    }

    private func logBlacklistDetails(_ blackListDevices: BlackListDevices) {
        let timestamp = TJLabsUtilFunctions.shared.getLocalTimeString()
        print("\(timestamp) , (TJLabsJupiter) Blacklist: iOS Devices = \(blackListDevices.iOS.apple)")
        print("\(timestamp) , (TJLabsJupiter) Blacklist: Updated Time = \(blackListDevices.updatedTime)")
    }

    public func decodeBlackListDevices(from jsonString: String) -> BlackListDevices? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(BlackListDevices.self, from: jsonData)
        } catch {
            print("Error decoding JSON: \(error)")
            return nil
        }
    }
}
