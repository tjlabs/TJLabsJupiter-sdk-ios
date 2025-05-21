
import TJLabsCommon
import TJLabsResource

class JupiterBuildingLevelChanger {
    static var buildingsAndLevelsMap = [String: [String]]()
    static var levelChangeAreaMap = [String: [[Double]]]()
    static var sectorDRModeArea = [String: DRModeArea]()
    
    static var currentDRModeArea = DRModeArea(number: -1, range: [], direction: 0, nodes: [])
    static var currentDRModeAreaNodeNumber: Int = -1
    
    static var buildingLevelChangedTime: Double = 0
    static var isDetermineSpot: Bool = false
    static var updatePositionInDRArea = [Double]()
    static var spotCutIndex: Int = 0
    static private var travelingOsrDistance: Double = 0
    static private var lastSpotId: Int = 0
    static private var currentSpot: Int = 0
    static private var buildingsAndLevels = [String: [String]]()
    static private var phase2Range = [Int]()
    static private var phase2Direction = [Int]()
    static private var preOutputMobileTime: Double = 0
    
    init() { }
    
    static func setBuildingLevelData(buildingLevel: [String: [String]]) {
        buildingsAndLevelsMap = buildingLevel
    }
    
    static func setSectorDRModeArea(key: String, data: [DRModeArea]) {
        for info in data {
            let updateKey = "\(key)_\(info.number)"
            sectorDRModeArea[updateKey] = info
        }
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
    
    static func checkInSectorDRModeArea(fltResult: FineLocationTrackingOutput, passedNodeInfo: PassedNodeInfo) -> Bool {
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: fltResult.level_name)
        let currentLevel = "_\(levelName)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentLevel) && key.contains("\(JupiterCalcManager.sectorId)_") {
                if (value.range[0] <= fltResult.x && fltResult.x <= value.range[2]) && (value.range[1] <= fltResult.y && fltResult.y <= value.range[3]) {
                    // 사용자 좌표가 영역 안에 존재
                    if value.direction == fltResult.absolute_heading {
                        // 사용자 방향이 일치함
                        for n in value.nodes {
                            // passedNode와 매칭 검사
                            if n.number == passedNodeInfo.nodeNumber {
                                // OSR 동작 시작
                                // 방향 결정 "U" or "D" or "N"
                                self.currentDRModeArea = value
                                self.currentDRModeAreaNodeNumber = n.number
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    static func checkOutSectorDRModeArea(fltResult: FineLocationTrackingOutput, anchorNodeInfo: PassedNodeInfo) -> Bool {
        if fltResult.level_name == "B0" {
            return true
        }
        
        var isInArea: Bool = false
        var isAnchorNodeInArea: Bool = false
        
        let currentLevel = "_\(fltResult.level_name)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentLevel) && key.contains("\(JupiterCalcManager.sectorId)_") {
                if (value.range[0] <= fltResult.x && fltResult.x <= value.range[2]) && (value.range[1] <= fltResult.y && fltResult.y <= value.range[3]) {
                    isInArea = true
                }
                
                if anchorNodeInfo.nodeCoord.isEmpty {
                    return false
                } else {
                    if (value.range[0] <= anchorNodeInfo.nodeCoord[0] && anchorNodeInfo.nodeCoord[0] <= value.range[2]) && (value.range[1] <= anchorNodeInfo.nodeCoord[1] && anchorNodeInfo.nodeCoord[1] <= value.range[3]) {
                        isAnchorNodeInArea = true
                    }
                }
            }
        }

        if !isInArea {
            if isAnchorNodeInArea {
               isInArea = true
            } else {
                self.currentDRModeArea = DRModeArea(number: -1, range: [], direction: 0, nodes: [])
                self.currentDRModeAreaNodeNumber = -1
            }
        }
        
        return isInArea
    }
    
    static func checkCoordInSectorDRModeArea(fltResult: FineLocationTrackingOutput) -> Bool {
        let currentLevel = "_\(fltResult.level_name)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentLevel) && key.contains("\(JupiterCalcManager.sectorId)_") {
                if (value.range[0] <= fltResult.x && fltResult.x <= value.range[2]) && (value.range[1] <= fltResult.y && fltResult.y <= value.range[3]) {
                    // 사용자 좌표가 영역 안에 존재
                    return true
                }
            }
        }
        return false
    }
    
    static func getSectorDRModeAreaSpotCoord(fltResult: FineLocationTrackingOutput, levelDirection: String) -> [Double] {
        let userDirectionType = levelDirection.contains("_D") ? "U" : "D"
        
        var spotCoord = [Double]()
        var minDistance: Double = Double(Int.max)
        
        // OSR이 동작하면 이 위치로 옮겨줌
        let currentBuildingLevel = "\(fltResult.building_name)_\(fltResult.level_name)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentBuildingLevel) && key.contains("\(JupiterCalcManager.sectorId)_") {
                let nodes = value.nodes
                for n in nodes {
                    if n.direction_type == userDirectionType {
                        let centerPos = n.center_pos
                        let diffX = fltResult.x - centerPos[0]
                        let diffY = fltResult.y - centerPos[1]
                        let distance = sqrt(diffX*diffX + diffY*diffY)
                        if distance < minDistance {
                            minDistance = distance
                            spotCoord = centerPos
                        }
                    }
                }
            }
        }
        return spotCoord
    }
}
