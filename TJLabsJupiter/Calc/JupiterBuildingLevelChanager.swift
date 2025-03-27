
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
            levelArray = makeLevelChangeArray(buildingName: building, levelNameInput: level, buildingLevel: buildingsAndLevelsMap)
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

    static func makeLevelChangeArray(buildingName: String, levelNameInput: String, buildingLevel: [String:[String]]) -> [String] {
        var levelArrayToReturn = [String]()
        
        if (!buildingLevel.isEmpty) {
            if (levelNameInput.contains("_D")) {
                let levelCandidate = levelNameInput.replacingOccurrences(of: "_D", with: "")
                levelArrayToReturn = [levelNameInput, levelCandidate]
            } else {
                let levelCandidate = levelNameInput + "_D"
                levelArrayToReturn = [levelNameInput, levelCandidate]
            }
            
            if let levelList: [String] = buildingLevel[buildingName] {
                var newArray = [String]()
                for i in 0..<levelArrayToReturn.count {
                    let levelName: String = levelArrayToReturn[i]
                    if levelList.contains(levelName) {
                        newArray.append(levelName)
                    }
                }
                
                if !newArray.isEmpty {
                    levelArrayToReturn = newArray
                } else {
                    levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
                }
            } else {
                levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
            }
        } else {
            levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
        }
        return levelArrayToReturn
    }
}
