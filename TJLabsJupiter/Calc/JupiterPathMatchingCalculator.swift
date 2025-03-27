
import TJLabsCommon
import TJLabsResource

class JupiterPathMatchingCalculator {
    static var shared = JupiterPathMatchingCalculator()
    
    var pathPixelData = [String: PathPixelData]()
    var entranceMatchingData = [String: [[Double]]]()
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 0
    
    init() { }
    
    func setPathPixelData(key: String, data: PathPixelData) {
        self.pathPixelData[key] = data
    }
    
    func setEntranceMatchingData(key: String, data: [[Double]]) {
        self.entranceMatchingData[key] = data
    }
    
    func pathMatching(region: String, sectorId: Int, building: String, level: String, x: Double, y: Double, heading: Double, headingRange: Double, isUseHeading: Bool, mode: UserMode, paddingValues: [Double]) -> (Bool, xyhs) {
        var isSuccess: Bool = false
        var xyhs = xyhs(x: x, y: y, heading: heading, scale: 1.0)
        var bestHeading = heading
        
        guard !building.isEmpty, !level.isEmpty else { return (isSuccess, xyhs) }
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let key = "\(sectorId)_\(building)_\(levelName)"
        
        let checkAvailablePathPixelResult = checkIsAvailablePathPixelData(key: key)
        let geoKey = "geofence_\(key)"
        guard let entranceMatchingArea = self.entranceMatchingData[geoKey] else { return (isSuccess, xyhs) }
        
        if checkAvailablePathPixelResult.0 {
            let pathPixelData = checkAvailablePathPixelResult.1
            let mainType = pathPixelData.roadType
            let mainRoad = pathPixelData.road
            let mainMagScale = pathPixelData.roadScale
            let mainHeading = pathPixelData.roadHeading
            let pathMatchingArea = self.checkInEntranceMatchingArea(entranceMatchingArea: entranceMatchingArea, x: x, y: y)
            var idshArray = [[Double]]()
            var idshArrayWhenFail = [[Double]]()
            
            if !mainRoad.isEmpty {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]

                var xMin = x - paddingValues[0]
                var xMax = x + paddingValues[2]
                var yMin = y - paddingValues[1]
                var yMax = y + paddingValues[3]
                
                if paddingValues[0] != 0 || paddingValues[1] != 0 || paddingValues[2] != 0 || paddingValues[3] != 0 {
                    if pathMatchingArea.0 {
                        xMin = pathMatchingArea.1[0]
                        yMin = pathMatchingArea.1[1]
                        xMax = pathMatchingArea.1[2]
                        yMax = pathMatchingArea.1[3]
                    }
                }
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    let pathTypeLoaded = mainType[i]

                    // Skip this path type if conditions aren't met
                    if mode == .MODE_VEHICLE && pathTypeLoaded == 0 { continue }

                    // Check if the path is within the bounding box
                    if xPath >= xMin && xPath <= xMax, yPath >= yMin && yPath <= yMax {
                        let distance = sqrt(pow(x - xPath, 2) + pow(y - yPath, 2))
                        let magScale = mainMagScale[i]
                        var idsh: [Double] = [Double(i), distance, magScale, heading]
                        idshArrayWhenFail.append(idsh)

                        if isUseHeading {
                            if let headingData = getHeadingDataArray(mainHeading[i]) {
                                let (isValid, correctedHeading) = validateHeading(heading: heading, headingRange: headingRange, headingData: headingData, x: xPath, y: yPath)
                                if isValid {
                                    idsh[3] = correctedHeading
                                    idshArray.append(idsh)
                                }
                            }
                        } else {
                            idshArray.append(idsh)
                        }
                    }
                }

                if !idshArray.isEmpty {
                    let updatedXyhs = processIdshArray(idshArray: idshArray, roadX: roadX, roadY: roadY, inputXyhs: &xyhs, bestHeading: &bestHeading, isUseHeading: isUseHeading)
                    xyhs = updatedXyhs
                    isSuccess = true
                } else {
                    let updatedXyhs = processFailedIdshArray(idshArrayWhenFail: idshArrayWhenFail, mainHeading: mainHeading, roadX: roadX, roadY: roadY, inputXyhs: &xyhs, bestHeading: &bestHeading)
                    xyhs = updatedXyhs
                }
            }
        }

        xyhs.heading = TJLabsUtilFunctions.shared.compensateDegree(xyhs.heading)
        return (isSuccess, xyhs)
    }
    
    func getPathMatchingHeadings(region: String, sectorId: Int, building: String, level: String, x: Double, y: Double, paddingValue: Double, mode: UserMode) -> [Double] {
        var headings: [Double] = []
        let levelCopy: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            let key: String = "\(sectorId)_\(building)_\(levelCopy)"
            let checkAvailablePathPixelResult = self.checkIsAvailablePathPixelData(key: key)
            if checkAvailablePathPixelResult.0 {
                let pathPixelData = checkAvailablePathPixelResult.1
                let mainType = pathPixelData.roadType
                let mainRoad = pathPixelData.road
                let mainHeading = pathPixelData.roadHeading
                
                if (!mainRoad.isEmpty) {
                    let roadX = mainRoad[0]
                    let roadY = mainRoad[1]
                    
                    let xMin = x - paddingValue
                    let xMax = x + paddingValue
                    let yMin = y - paddingValue
                    let yMax = y + paddingValue
                    
                    for i in 0..<roadX.count {
                        let xPath = roadX[i]
                        let yPath = roadY[i]
                        
                        let pathTypeLoaded = mainType[i]
                        if (mode == .MODE_VEHICLE) {
                            if (pathTypeLoaded == 0) {
                                continue
                            }
                        }
                        
                        if (xPath >= xMin && xPath <= xMax) {
                            if (yPath >= yMin && yPath <= yMax) {
                                let headingArray = mainHeading[i]
                                if (!headingArray.isEmpty) {
                                    let headingData = headingArray.components(separatedBy: ",")
                                    for j in 0..<headingData.count {
                                        if (!headingData[j].isEmpty) {
                                            let value = Double(headingData[j])!
                                            if (!headings.contains(value)) {
                                                headings.append(value)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return headings
    }
    
    private func checkIsAvailablePathPixelData(key: String) -> (Bool, PathPixelData) {
        let emptyPathPixelData = PathPixelData(roadType: [], nodeNumber: [], road: [[]], roadMinMax: [], roadScale: [], roadHeading: [])
        guard let pathPixelData = self.pathPixelData[key] else {
            return (false, emptyPathPixelData)
        }
        
        let mainType = pathPixelData.roadType
        if mainType.isEmpty { return (false, emptyPathPixelData) }
        
        let mainRoad = pathPixelData.road
        if mainRoad.isEmpty { return (false, emptyPathPixelData) }
        
        let mainMagScale = pathPixelData.roadScale
        if mainMagScale.isEmpty { return (false, emptyPathPixelData) }
        
        let mainHeading = pathPixelData.roadHeading
        if mainHeading.isEmpty { return (false, emptyPathPixelData) }
        
        return (true, pathPixelData)
    }
    
    func checkInEntranceMatchingArea(entranceMatchingArea: [[Double]], x: Double, y: Double) -> (Bool, [Double]) {
        var area = [Double]()
        
        for i in 0..<entranceMatchingArea.count {
            if (!entranceMatchingArea[i].isEmpty) {
                let xMin = entranceMatchingArea[i][0]
                let yMin = entranceMatchingArea[i][1]
                let xMax = entranceMatchingArea[i][2]
                let yMax = entranceMatchingArea[i][3]
                
                if (x >= xMin && x <= xMax) {
                    if (y >= yMin && y <= yMax) {
                        area = entranceMatchingArea[i]
                        return (true, area)
                    }
                }
            }
        }
        
        return (false, area)
    }
    
    private func getHeadingDataArray(_ headingString: String) -> [Double]? {
        let headingData = headingString.components(separatedBy: ",").compactMap { Double($0) }
        return headingData.isEmpty ? nil : headingData
    }

    private func validateHeading(heading: Double, headingRange: Double, headingData: [Double], x: Double, y: Double) -> (Bool, Double) {
        var diffHeading = [Double]()
        for mapHeading in headingData {
            let adjustedHeading = adjustHeading(heading, mapHeading)
            diffHeading.append(abs(adjustedHeading))
        }
        if let minHeading = diffHeading.min() {
            let valid = minHeading < headingRange
            return (valid, headingData[diffHeading.firstIndex(of: minHeading)!])
        }
        return (false, heading)
    }

    private func adjustHeading(_ heading: Double, _ mapHeading: Double) -> Double {
        if heading > 270 && mapHeading < 90 {
            return abs(heading - (mapHeading + 360))
        } else if mapHeading > 270 && heading < 90 {
            return abs(mapHeading - (heading + 360))
        } else {
            return abs(heading - mapHeading)
        }
    }
    
    private func processIdshArray(idshArray: [[Double]], roadX: [Double], roadY: [Double], inputXyhs: inout xyhs, bestHeading: inout Double, isUseHeading: Bool) -> xyhs {
        let sortedIdsh = idshArray.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            let correctedScale = max(minData[2], 0.7)
            let correctedHeading = isUseHeading ? minData[3] : inputXyhs.heading
            let updatedXyhs: xyhs = xyhs(x: roadX[index], y: roadY[index], heading: correctedHeading, scale: correctedScale)
            bestHeading = correctedHeading
            return updatedXyhs
        } else {
            return inputXyhs
        }
    }

    private func processFailedIdshArray(idshArrayWhenFail: [[Double]], mainHeading: [String], roadX: [Double], roadY: [Double], inputXyhs: inout xyhs, bestHeading: inout Double) -> xyhs {
        let sortedIdsh = idshArrayWhenFail.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            let updatedXyhs = xyhs(x: roadX[index], y: roadY[index], heading: inputXyhs.heading, scale: max(minData[2], 0.7))
            if let headingData = getHeadingDataArray(mainHeading[index]) {
                bestHeading = headingData.min() ?? inputXyhs.heading
            }
            return updatedXyhs
        } else {
            return inputXyhs
        }
    }
}
