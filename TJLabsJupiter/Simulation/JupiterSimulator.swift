
import TJLabsCommon
import TJLabsResource

class JupiterSimulator {
    static let shared = JupiterSimulator()
    init() { }
    
    var isSimulationMode: Bool = false
    var bleFileName: String = ""
    var sensorFileName: String = ""
    
    var simulationBleData = [[String: Double]]()
    var simulationSensorData = [SensorData]()
    var simulationTime: Double = 0
    var bleLineCount: Int = 0
    var sensorLineCount: Int = 0
    
    func setSimulationMode(flag: Bool, bleFileName: String, sensorFileName: String) {
        self.isSimulationMode = flag
        self.bleFileName = bleFileName
        self.sensorFileName = sensorFileName
        
        if (self.isSimulationMode) {
            let result = JupiterFileManager.shared.loadFilesForSimulation(bleFile: self.bleFileName, sensorFile: self.sensorFileName)
            simulationBleData = result.0
            simulationSensorData = result.1
            simulationTime = TJLabsUtilFunctions.shared.getCurrentTimeInMillisecondsDouble()
        }
    }
    
    func getSimulationBleData() -> [String: Double] {
        var bleAvg = [String: Double]()
        if bleLineCount < simulationBleData.count-1 {
            bleAvg = simulationBleData[bleLineCount]
        }
        bleLineCount += 1
        return bleAvg
    }
    
    func getSimulationSensorData() {
        if sensorLineCount < simulationSensorData.count-1 {
            
        } else {
            
        }
        sensorLineCount += 1
    }
}
