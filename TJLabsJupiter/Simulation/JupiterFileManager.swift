
import Foundation
import TJLabsCommon

public class JupiterFileManager {
    static let shared = JupiterFileManager()
    
    private let dataQueue = DispatchQueue(label: "tjlabs.jupiter.dataQueue", attributes: .concurrent)
    
    var sensorFileUrl: URL? = nil
    var bleFileUrl: URL? = nil
    
    var sensorData = [SensorData]()
    var bleTime = [Int]()
    var bleData = [[String: Double]]()
    
    var region: String = ""
    var sector_id: Int = 0
    var deviceModel: String = "Unknown"
    var osVersion: Int = 0
    
//    var collectFileUrl: URL? = nil
//    var collectData = [OlympusCollectData]()
    
    init() {}
    
    public func initalize() {
        region = ""
        sector_id = 0
        deviceModel = "Unknown"
        osVersion = 0
        
        sensorData = [SensorData]()
        bleTime = [Int]()
        bleData = [[String: Double]]()
        
//        collectFileUrl = nil
//        collectData = [OlympusCollectData]()
    }
    
    public func setRegion(region: String) {
        self.region = region
    }
    
    private func createExportDirectory() -> URL? {
        guard let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("(TJLabsJupiter) FileManager : Unable to access document directory.")
            return nil
        }
        let exportDirectoryUrl = documentDirectoryUrl.appendingPathComponent("Exports")
        if !FileManager.default.fileExists(atPath: exportDirectoryUrl.path) {
            do {
                try FileManager.default.createDirectory(at: exportDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
                print("(TJLabsJupiter) FileManager : Export directory created at: \(exportDirectoryUrl)")
            } catch {
                print("(TJLabsJupiter) FileManager : Error creating export directory: \(error)")
                return nil
            }
        } else {
            print("(TJLabsJupiter) FileManager : Export directory already exists at: \(exportDirectoryUrl)")
        }
        
        return exportDirectoryUrl
    }
    
    public func createFiles(region: String, sector_id: Int, deviceModel: String, osVersion: Int) {
        if let exportDir: URL = self.createExportDirectory() {
            self.region = region
            self.sector_id = sector_id
            self.deviceModel = deviceModel
            self.osVersion = osVersion
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            dateFormatter.locale = Locale(identifier:"ko_KR")
            let nowDate = Date()
            let convertNowStr = dateFormatter.string(from: nowDate)
            
            let sensorFileName = "ios_\(region)_\(sector_id)_\(convertNowStr)_\(deviceModel)_\(osVersion)_sensor.csv"
            let bleFileName = "ios_\(region)_\(sector_id)_\(convertNowStr)_\(deviceModel)_\(osVersion)_ble.csv"
            sensorFileUrl = exportDir.appendingPathComponent(sensorFileName)
            bleFileUrl = exportDir.appendingPathComponent(bleFileName)
        } else {
            print("(TJLabsJupiter) FileManager : Error creating export directory")
        }
    }
    
    public func writeSensorData(currentTime: Double, data: SensorData) {
        dataQueue.async(flags: .barrier) {
            var sensorRow = data
            sensorRow.time = Int(currentTime)
            self.sensorData.append(sensorRow)
        }
    }
    
    public func writeBleData(time: Int, data: [String: Double]) {
        dataQueue.async(flags: .barrier) {
            self.bleTime.append(time)
            self.bleData.append(data)
        }
    }
    
    private func saveSensorData() {
        let dataToSave = sensorData
        
        var csvText = "time,acc_x,acc_y,acc_z,u_acc_x,u_acc_y,u_acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z,grav_x,grav_y,grav_z,att0,att1,att2,q0,q1,q2,q3,rm00,rm01,rm02,rm10,rm11,rm12,rm20,rm21,rm22,gv0,gv1,gv2,gv3,rv0,rv1,rv2,rv3,rv4,pressure,true_heading,mag_heading\n"
        for record in dataToSave {
            csvText += "\(record.time),\(record.acc[0]),\(record.acc[1]),\(record.acc[2]),\(record.userAcc[0]),\(record.userAcc[1]),\(record.userAcc[2]),\(record.gyro[0]),\(record.gyro[1]),\(record.gyro[2]),\(record.mag[0]),\(record.mag[1]),\(record.mag[2]),\(record.grav[0]),\(record.grav[1]),\(record.grav[2]),\(record.att[0]),\(record.att[1]),\(record.att[2]),\(record.quaternion[0]),\(record.quaternion[1]),\(record.quaternion[2]),\(record.quaternion[3]),\(record.rotationMatrix[0][0]),\(record.rotationMatrix[0][1]),\(record.rotationMatrix[0][2]),\(record.rotationMatrix[1][0]),\(record.rotationMatrix[1][1]),\(record.rotationMatrix[1][2]),\(record.rotationMatrix[2][0]),\(record.rotationMatrix[2][1]),\(record.rotationMatrix[2][2]),\(record.gameVector[0]),\(record.gameVector[1]),\(record.gameVector[2]),\(record.gameVector[3]),\(record.rotVector[0]),\(record.rotVector[1]),\(record.rotVector[2]),\(record.rotVector[3]),\(record.rotVector[4]),\(record.pressure[0]),\(record.trueHeading),\(record.magneticHeading)\n"
        }
        do {
            if let fileUrl = sensorFileUrl {
                try csvText.write(to: fileUrl, atomically: true, encoding: .utf8)
                print("(TJLabsJupiter) FileManager : Data saved to \(fileUrl)")
            } else {
                print("(TJLabsJupiter) FileManager : Error: sensorFileUrl is nil")
            }
        } catch {
            print("(TJLabsJupiter) FileManager : Error: \(error)")
        }
        
        sensorData = [SensorData]()
    }
    
    private func saveBleData() {
        let dataTime = bleTime
        let dataToSave = bleData
        
        var csvText = "time,ble\n"
        for i in 0..<dataTime.count {
            csvText += "\(dataTime[i]),"
            let record = dataToSave[i]
            for (key, value) in record {
                csvText += "\(key):\(value),"
            }
            csvText += "\n"
        }
        print("(TJLabsJupiter) FileManager : ble csvText = \(csvText)")
        do {
            if let fileUrl = bleFileUrl {
                try csvText.write(to: fileUrl, atomically: true, encoding: .utf8)
                print("(TJLabsJupiter) FileManager : Data saved to \(fileUrl)")
            } else {
                print("(TJLabsJupiter) FileManager : Error: bleFileUrl is nil")
            }
        } catch {
            print("(TJLabsJupiter) FileManager : Error: \(error)")
        }
        
        bleTime = [Int]()
        bleData = [[String: Double]]()
    }
    
    public func saveFilesForSimulation() {
        saveBleData()
        saveSensorData()
    }
    
    public func loadFilesForSimulation(bleFile: String, sensorFile: String) -> ([[String: Double]], [SensorData]) {
        var loadedBleData = [[String: Double]]()
        var loadedSenorData = [SensorData]()
        
        if let exportDir: URL = self.createExportDirectory() {
            let bleFileName = bleFile
            let sensorFileName = sensorFile
            
            let bleSimulationUrl = exportDir.appendingPathComponent(bleFileName)
            print("(TJLabsJupiter) FileManager : bleSimulationUrl = \(bleSimulationUrl)")
            do {
                let csvData = try String(contentsOf: bleSimulationUrl)
                let bleRows = csvData.components(separatedBy: "\n")
                for row in bleRows {
                    let replacedRow = row.replacingOccurrences(of: "\r", with: "")
                    let columns = replacedRow.components(separatedBy: ",")
                    if columns[0] != "time" {
                        var bleDict = [String: Double]()
                        if (columns.count > 1) {
                            for i in 0..<columns.count {
                                if i == 0 {
                                    // time
                                } else {
                                    if (columns[i].count > 1) {
                                        let bleKeyValue = columns[i].components(separatedBy: ":")
                                        let bleKey = bleKeyValue[0]
                                        let bleValue = Double(bleKeyValue[1])!
                                        bleDict[bleKey] = bleValue
                                    }
                                }
                            }
                        }
                        
                        loadedBleData.append(bleDict)
                    }
                }
            } catch {
                print("(TJLabsJupiter) FileManager : Error loading sensor file: \(error)")
            }
            

            let sensorSimulationUrl = exportDir.appendingPathComponent(sensorFileName)
            print("(TJLabsJupiter) FileManager : sensorSimulationUrl = \(sensorSimulationUrl)")
            do {
                let csvData = try String(contentsOf: sensorSimulationUrl)
                let sensorRows = csvData.components(separatedBy: "\n")
                for row in sensorRows {
                    let replacedRow = row.replacingOccurrences(of: "\r", with: "")
                    let columns = replacedRow.components(separatedBy: ",")
                    if columns[0] != "time" && columns.count > 1 {
                        var sensorData = SensorData()
                        sensorData.time = Int(Double(columns[0])!)
                        sensorData.acc = [Double(columns[1])!, Double(columns[2])!, Double(columns[3])!]
                        sensorData.userAcc = [Double(columns[4])!, Double(columns[5])!, Double(columns[6])!]
                        sensorData.gyro = [Double(columns[7])!, Double(columns[8])!, Double(columns[9])!]
                        sensorData.mag = [Double(columns[10])!, Double(columns[11])!, Double(columns[12])!]
                        sensorData.grav = [Double(columns[13])!, Double(columns[14])!, Double(columns[15])!]
                        sensorData.att = [Double(columns[16])!, Double(columns[17])!, Double(columns[18])!]
                        sensorData.quaternion = [Double(columns[19])!, Double(columns[20])!, Double(columns[21])!, Double(columns[22])!]
                        sensorData.rotationMatrix = [[Double(columns[23])!, Double(columns[24])!, Double(columns[25])!], [Double(columns[26])!, Double(columns[27])!, Double(columns[28])!], [Double(columns[29])!, Double(columns[30])!, Double(columns[31])!]]
                        sensorData.gameVector = [Float(columns[32])!, Float(columns[33])!, Float(columns[34])!, Float(columns[35])!]
                        sensorData.rotVector = [Float(columns[36])!, Float(columns[37])!, Float(columns[38])!, Float(columns[39])!, Float(columns[40])!]
                        sensorData.pressure = [Double(columns[41])!]
                        if (columns.count > 42) {
                            sensorData.trueHeading = Double(columns[42])!
                            sensorData.magneticHeading = Double(columns[43])!
                        }
                        loadedSenorData.append(sensorData)
                    }
                }
            } catch {
                print("(TJLabsJupiter) FileManager : Error loading sensor file: \(error)")
            }
            
        } else {
            print("(TJLabsJupiter) FileManager : Error creating export directory")
        }
        
        return (loadedBleData, loadedSenorData)
    }
    
//    public func createCollectFile(region: String, deviceModel: String, osVersion: Int) {
//        if let exportDir: URL = self.createExportDirectory() {
//            self.region = region
//            self.deviceModel = deviceModel
//            self.osVersion = osVersion
//            
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "yyyyMMddHHmmss"
//            dateFormatter.locale = Locale(identifier:"ko_KR")
//            let nowDate = Date()
//            let convertNowStr = dateFormatter.string(from: nowDate)
//            
//            let collectFileName = "ios_collect_\(region)_\(convertNowStr)_\(deviceModel)_\(osVersion).csv"
//            collectFileUrl = exportDir.appendingPathComponent(collectFileName)
//        } else {
//            print("(Olympus) FileManager : Error creating export directory in collect")
//        }
//    }
//    
//    public func writeCollectData(data: OlympusCollectData) {
//        dataQueue.async(flags: .barrier) {
//            self.collectData.append(data)
//        }
//    }
//    
//    public func saveCollectData() {
//        let dataToSave = self.collectData
//        var csvText = "time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z,roll,pitch,yaw,qx,qy,qz,qw,pressure,true_heading,mag_heading,ble\n"
//        print("(Olympus) FileManager : collect = \(dataToSave)")
//        for record in dataToSave {
//            let bleData = record.bleAvg
//            let bleString = (bleData.flatMap({ (key, value) -> String in
//                let str = String(format: "%.2f", value)
//                return "\(key),\(str)"
//            }) as Array).joined(separator: ",")
//            
//            csvText += "\(record.time),\(record.acc[0]),\(record.acc[1]),\(record.acc[2]),\(record.gyro[0]),\(record.gyro[1]),\(record.gyro[2]),\(record.mag[0]),\(record.mag[1]),\(record.mag[2]),\(record.att[0]),\(record.att[1]),\(record.att[2]),\(record.quaternion[0]),\(record.quaternion[1]),\(record.quaternion[2]),\(record.quaternion[3]),\(record.pressure[0]),\(record.trueHeading),\(record.magneticHeading),\(bleString)\n"
//        }
//        print("(Olympus) FileManager : collect csvText = \(csvText)")
//        do {
//            if let fileUrl = collectFileUrl {
//                try csvText.write(to: fileUrl, atomically: true, encoding: .utf8)
//                print("(Olympus) FileManager : Data saved to \(fileUrl)")
//            } else {
//                print("(Olympus) FileManager : Error: collectFileUrl is nil")
//            }
//        } catch {
//            print("(Olympus) FileManager : Error: \(error)")
//        }
//        
//        collectData = [OlympusCollectData]()
//    }
}
