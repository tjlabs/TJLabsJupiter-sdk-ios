
import Foundation
import TJLabsCommon

class JupiterRssCompensator {
    static var deviceMin: Double = -99
    private static var standardMin: Double = -99
    private static var standardMax: Double = -60
    
    private static var entranceWardRssi = [String: Double]()
    private static var allEntranceWardRssi = [String: Double]()
    
    private static var wardMinRssi = [Double]()
    private static var wardMaxRssi = [Double]()
    
    static var isScaleLoaded: Bool = false
    static var isScaleSaved: Bool = false
    static var isScaleConverged: Bool = false
    
    private static var timeAfterResponse: Double = 0
    private static var normalizationScale: Double = 1.0
    private static var preNormalizationScale: Double = 1.0
    private static var preSmoothedNormalizationScale: Double = 1.0
    private static var scaleQueue = [Double]()
    private static var estRssCompenstaionTimeStamp: Double = 0
    private static var timeStackEst: Double = 0
    
    private static var updateMinArrayCount: Int = 0
    private static var updateMaxArrayCount: Int = 0
    private static let ARRAY_SIZE: Int = 3
    
    static func initializeTimeStack() {
        self.timeAfterResponse = 0
        self.timeStackEst = 0
    }
    
    static func setStandardMinMax(minMax: [Int]) {
        standardMin = Double(minMax[0])
        standardMax = Double(minMax[1])
    }
    
    static func estimateNormalizationScale(isGetFirstResponse: Bool, isIndoor: Bool, currentLevel: String, diffMinMaxRssi: Double, minRssi: Double) {
        self.timeStackEst += JupiterTime.RFD_INTERVAL
        
        if (isGetFirstResponse && isIndoor && diffMinMaxRssi >= 25 && minRssi <= -97 && self.timeStackEst >= JupiterRssCompensation.EST_RC_INTERVAL) {
            self.timeStackEst = 0
            if (self.isScaleLoaded) {
                if (currentLevel != "B0") {
                    let normalizationScale = calNormalizationScale(standardMin: standardMin, standardMax: standardMax)
                    if (!self.isScaleConverged) {
                        if (normalizationScale.0) {
                            let smoothedScale: Double = smoothNormalizationScale(scale: normalizationScale.1)
                            self.normalizationScale = smoothedScale
                            let diffScale = abs(smoothedScale - self.preNormalizationScale)
                            if (diffScale < 1e-3 && self.timeAfterResponse >= JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
                                self.isScaleConverged = true
                            }
                            self.preNormalizationScale = smoothedScale
                        }
                    }
                }
            } else {
                if (!self.isScaleConverged) {
                    let normalizationScale = calNormalizationScale(standardMin: standardMin, standardMax: standardMax)
                    if (normalizationScale.0) {
                        let smoothedScale: Double = smoothNormalizationScale(scale: normalizationScale.1)
                        self.normalizationScale = smoothedScale
                        let diffScale = abs(smoothedScale - self.preNormalizationScale)
                        if (diffScale < 1e-3 && self.timeAfterResponse >= JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
                            self.isScaleConverged = true
                        }
                        self.preNormalizationScale = smoothedScale
                    } else {
                        let smoothedScale: Double = smoothNormalizationScale(scale: self.preNormalizationScale)
                        self.normalizationScale = smoothedScale
                    }
                }
            }
        }
    }
    
    static func loadRssiCompensationParam(sector_id: Int, device_model: String, os_version: Int, completion: @escaping (Bool, Double, String) -> Void) {
        var loadedNormalizationScale: Double = 1.0
        
        // Check data in cache
        let loadedScale = loadNormalizationScaleFromCache(sector_id: sector_id)
        
        if loadedScale.0 {
            // Scale is in cache
            loadedNormalizationScale = loadedScale.1
            let msg: String = "(JupiterRssCompensator) Success : Load RssCompensation in cache"
            completion(true, loadedNormalizationScale, msg)
        } else {
            let rcDeviceOsInput = RcDeviceOsInput(sector_id: sector_id, device_model: device_model, os_version: os_version)
            JupiterNetworkManager.shared.getUserRssCompensation(url: JupiterNetworkConstants.getUserRcURL(), input: rcDeviceOsInput, isDeviceOs: true, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    let rcResult = jsonToRcInfoFromServer(jsonString: returnedString)
                    if (rcResult.0) {
                        if (rcResult.1.rss_compensations.isEmpty) {
                            let rcDeviceInput = RcDeviceInput(sector_id: sector_id, device_model: device_model)
                            JupiterNetworkManager.shared.getUserRssCompensation(url: JupiterNetworkConstants.getUserRcURL(), input: rcDeviceInput, isDeviceOs: false, completion: { statusCode, returnedString in
                                if (statusCode == 200) {
                                    let rcDeviceResult = jsonToRcInfoFromServer(jsonString: returnedString)
                                    if (rcDeviceResult.0) {
                                        if (rcDeviceResult.1.rss_compensations.isEmpty) {
                                            // Need Normalization-scale Estimation
                                            print("(JupiterRssCompensator) Information : Need RssCompensation Estimation")
                                            let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                            completion(true, loadedNormalizationScale, msg)
                                        } else {
                                            // Succes Load Normalization-scale (Device)
                                            if let closest = self.findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
                                                // Find Closest OS
                                                let rcFromServer: RcInfo = closest
                                                loadedNormalizationScale = rcFromServer.normalization_scale
                                                
                                                print("(JupiterRssCompensator) Information : Load RssCompensation from server (\(device_model))")
                                                let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            } else {
                                                // Need Normalization-scale Estimation
                                                print("(JupiterRssCompensator) Information : Need RssCompensation Estimation")
                                                let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            }
                                        }
                                    } else {
                                        let msg: String = "(JupiterRssCompensator) Error : Decode RssCompensation (\(device_model))"
                                        completion(false, loadedNormalizationScale, msg)
                                    }
                                } else {
                                    let msg: String = "(JupiterRssCompensator) Error : Load RssCompensation (\(device_model)) from server \(statusCode)"
                                    completion(false, loadedNormalizationScale, msg)
                                }
                            })
                        } else {
                            // Succes Load Normalization-scale (Device & OS)
                            let rcFromServer: RcInfo = rcResult.1.rss_compensations[0]
                            loadedNormalizationScale = rcFromServer.normalization_scale
                            
                            print("(JupiterRssCompensator) Information : Load RssCompensation from server (\(device_model) & \(os_version))")
                            let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                            completion(true, loadedNormalizationScale, msg)
                        }
                    } else {
                        let msg: String = "(JupiterRssCompensator) Error : Decode RssCompensation (\(device_model) & \(os_version))"
                        completion(false, loadedNormalizationScale, msg)
                    }
                } else {
                    let msg: String = "(JupiterRssCompensator) Error : Load RssCompensation (\(device_model) & \(os_version)) from server \(statusCode)"
                    completion(false, loadedNormalizationScale, msg)
                }
            })
        }
    }
    
    static func findClosestOs(to myOsVersion: Int, in array: [RcInfo]) -> RcInfo? {
        guard let first = array.first else {
            return nil
        }
        var closest = first
        var closestDistance = closest.os_version - myOsVersion
        for d in array {
            let distance = d.os_version - myOsVersion
            if abs(distance) < abs(closestDistance) {
                closest = d
                closestDistance = distance
            }
        }
        return closest
    }
    
    static func saveNormalizationScaleToCache(sector_id: Int) {
        print("(JupiterRssCompensator) Save NormalizationScale : \(normalizationScale)")
        
        do {
            let key: String = "JupiterNormalizationScale_\(sector_id)"
            UserDefaults.standard.set(scale, forKey: key)
        }
    }
    
    static func loadNormalizationScaleFromCache(sector_id: Int) -> (Bool, Double) {
        var isLoadedFromCache: Bool = false
        var scale: Double = 1.0
        
        let keyScale: String = "JupiterNormalizationScale_\(sector_id)"
        if let loadedScale: Double = UserDefaults.standard.object(forKey: keyScale) as? Double {
            scale = loadedScale
            isLoadedFromCache = true
            if (scale >= 1.7) {
                scale = 1.0
            }
        }
        
        return (isLoadedFromCache, scale)
    }
    
    static func getMinRssi() -> Double {
        if (self.wardMinRssi.isEmpty) {
            return -60.0
        } else {
            let avgMin = self.wardMinRssi.average
            return avgMin
        }
    }
    
    static func getMaxRssi() -> Double {
        if (self.wardMaxRssi.isEmpty) {
            return -90.0
        } else {
            let avgMax = self.wardMaxRssi.average
            return avgMax
        }
    }
    
    static func refreshWardMinRssi(bleData: [String: Double]) {
        for (_, value) in bleData {
            if (value > -100) {
                if (self.wardMinRssi.isEmpty) {
                    self.wardMinRssi.append(value)
                } else {
                    let newArray = appendAndKeepMin(inputArray: self.wardMinRssi, newValue: value)
                    self.wardMinRssi = newArray
                }
            }
        }
    }
    
    static func refreshWardMaxRssi(bleData: [String: Double]) {
        for (_, value) in bleData {
            if (self.wardMaxRssi.isEmpty) {
                self.wardMaxRssi.append(value)
            } else {
                let newArray = appendAndKeepMax(inputArray: self.wardMaxRssi, newValue: value)
                self.wardMaxRssi = newArray
            }
        }
    }
    
    static func calNormalizationScale(standardMin: Double, standardMax: Double) -> (Bool, Double) {
        let standardAmplitude: Double = abs(standardMax - standardMin)
        if (wardMaxRssi.isEmpty || wardMinRssi.isEmpty) {
            return (false, 1.0)
        } else {
            let avgMax = wardMaxRssi.average
            let avgMin = wardMinRssi.average
            
            deviceMin = avgMax
            let amplitude: Double = abs(avgMax - avgMin)
            
            let digit: Double = pow(10, 4)
            var normalizationScale: Double = (standardAmplitude/amplitude)*digit/digit
            
            if normalizationScale > 1.2 {
                normalizationScale = 1.2
            } else if normalizationScale < 0.8 {
                normalizationScale = 0.8
            }
            updateScaleQueue(data: normalizationScale)
            print("(JupiterRssCompensator) : wardMaxRssi = \(wardMaxRssi) // wardMinRssi = \(wardMinRssi) // standardMax = \(standardMax) // standardMin = \(standardMin) // normalizationScale = \(normalizationScale)")
            
            return (true, normalizationScale)
        }
    }
    
    static func updateScaleQueue(data: Double) {
        if (self.scaleQueue.count >= 10) {
            self.scaleQueue.remove(at: 0)
        }
        self.scaleQueue.append(data)
    }
    
    static func smoothNormalizationScale(scale: Double) -> Double {
        var smoothedScale: Double = 1.0
        if (self.scaleQueue.count == 1) {
            smoothedScale = scale
        } else {
            smoothedScale = movingAverage(preMvalue: self.preSmoothedNormalizationScale, curValue: scale, windowSize: self.scaleQueue.count)
        }
        self.preSmoothedNormalizationScale = smoothedScale
        
        return smoothedScale
    }
    
    static func appendAndKeepMin(inputArray: [Double], newValue: Double) -> [Double] {
        var array: [Double] = inputArray
        array.append(newValue)
        if array.count > JupiterRssCompensation.ARRAY_SIZE {
            if let maxValue = array.max() {
                if let index = array.firstIndex(of: maxValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    static func appendAndKeepMax(inputArray: [Double], newValue: Double) -> [Double] {
        var array: [Double] = inputArray
        array.append(newValue)
        
        if array.count > JupiterRssCompensation.ARRAY_SIZE {
            if let minValue = array.min() {
                if let index = array.firstIndex(of: minValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    static func movingAverage(preMvalue: Double, curValue: Double, windowSize: Int) -> Double {
        let windowSizeDouble: Double = Double(windowSize)
        return preMvalue*((windowSizeDouble - 1)/windowSizeDouble) + (curValue/windowSizeDouble)
    }
    
    static func stackTimeAfterResponse() {
        if (self.timeAfterResponse < JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME) {
            self.timeAfterResponse += JupiterTime.RFD_INTERVAL
        }
    }
    
    static func jsonToRcInfoFromServer(jsonString: String) -> (Bool, RcInfoOutputList) {
        let result = RcInfoOutputList(rss_compensations: [])
        
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                let decodedData: RcInfoOutputList = try JSONDecoder().decode(RcInfoOutputList.self, from: jsonData)
                return (true, decodedData)
            } catch {
                print("Error decoding JSON: \(error)")
                return (false, result)
            }
        } else {
            return (false, result)
        }
    }
}
