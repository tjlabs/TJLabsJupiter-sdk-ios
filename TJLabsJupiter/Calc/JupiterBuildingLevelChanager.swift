
import TJLabsCommon

class JupiterBuildingLevelChanager {
    static var buildingsAndLevelsMap = [String: [String]]()
    static var levelChangeAreaMap = [String: [[Double]]]()
    
    init() { }
    
    static func setBuildingLevelData(buildingLevel: [String: [String]]) {
        buildingsAndLevelsMap = buildingLevel
    }
    
    static func setLevelChangeArea(key: String, data: [[Double]]) {
        levelChangeAreaMap[key] = data
    }
    
    static func makeLevelList(sectorId: Int, building: String, level: String, x: Double, y: Double, mode: UserMode) -> [String] {
        var levelArray = [level]
        let isInLevelChangeArea = checkInLevelChangeArea(sectorId: sectorId, building: building, level: level, x: x, y: y, mode: mode)
        
        if isInLevelChangeArea {
            levelArray = makeLevelChangeArray(buildingName: building, levelName: level, buildingLevel: buildingsAndLevelsMap)
        }
        
        return levelArray
    }
    
    static func checkInLevelChangeArea(sectorId: Int, building: String, level: String, x: Double, y: Double, mode: UserMode) -> Bool {
        if mode == .MODE_PEDESTRIAN { return false }
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let key = "\(sectorId)_\(building)_\(levelName)"
        guard let levelChangeArea: [[Double]] = levelChangeAreaMap[key] else { return false }
        
        for i in 0..<levelChangeArea.count {
            if (!levelChangeArea[i].isEmpty) {
                let xMin = levelChangeArea[i][0]
                let yMin = levelChangeArea[i][1]
                let xMax = levelChangeArea[i][2]
                let yMax = levelChangeArea[i][3]
                
                if (x >= xMin && x <= xMax) {
                    if (y >= yMin && y <= yMax) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    static func makeLevelChangeArray(buildingName: String, levelName: String, buildingLevel: [String:[String]]) -> [String] {
        let inputLevel = levelName
        var levelArrayToReturn: [String] = [levelName]
        
        if (inputLevel.contains("_D")) {
            let levelCandidate = inputLevel.replacingOccurrences(of: "_D", with: "")
            levelArrayToReturn = [inputLevel, levelCandidate]
        } else {
            let levelCandidate = inputLevel + "_D"
            levelArrayToReturn = [inputLevel, levelCandidate]
        }
        
        if (!buildingLevel.isEmpty) {
            guard let levelList: [String] = buildingLevel[buildingName] else {
                return levelArrayToReturn
            }
            
            var newArray = [String]()
            for i in 0..<levelArrayToReturn.count {
                let levelName: String = levelArrayToReturn[i]
                if (levelList.contains(levelName)) {
                    newArray.append(levelName)
                }
            }
            levelArrayToReturn = newArray
        }
        
        return levelArrayToReturn
    }
}
