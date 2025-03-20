
import TJLabsCommon
import TJLabsResource

class JupiterPathMatchingCalculator {
    static var shared = JupiterPathMatchingCalculator()
    
    var pathPixelData = [String: PathPixelData]()
    var entranceMatchingData = [String: [[Double]]]()
    
    init() { }
    
    func setPathPixelData(key: String, data: PathPixelData) {
        self.pathPixelData[key] = data
    }
    
    func setEntranceMatchingData(key: String, data: [[Double]]) {
        self.entranceMatchingData[key] = data
    }
    
    func pathMatching(key: String, result: JupiterResult, headingRange: Double, isUseHeading: Bool, mode: UserMode, paddingValues: [Double]) -> xyhs {
        
        let x = result.x
        let y = result.y
        let heading = result.absolute_heading
        let building = result.building_name
        let level = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: result.level_name)
        
        var xyhs = xyhs(x: x, y: y, heading: heading, scale: 1.0)
        var bestHeading = heading
        
        guard let pathPixelData = self.pathPixelData[key] else { return xyhs }
        guard let entranceMatchingArea = self.entranceMatchingData[key] else { return xyhs }
        
        guard !building.isEmpty, !level.isEmpty,
              let mainType = self.pathPixelData[key]?.roadType,
              let mainRoad = self.pathPixelData[key]?.road,
              let mainMagScale = self.pathPixelData[key]?.roadScale,
              let mainHeading = self.pathPixelData[key]?.roadHeading else {
            return xyhs
        }
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
                            let (isValid, correctedHeading) = validateHeading(heading: heading, HEADING_RANGE: headingRange, headingData: headingData, x: xPath, y: yPath)
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
            } else {
                let updatedXyhs = processFailedIdshArray(idshArrayWhenFail: idshArrayWhenFail, mainHeading: mainHeading, roadX: roadX, roadY: roadY, inputXyhs: &xyhs, bestHeading: &bestHeading)
                xyhs = updatedXyhs
            }
        }

        xyhs.heading = TJLabsUtilFunctions.shared.compensateDegree(xyhs.heading)
        return xyhs
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

    private func validateHeading(heading: Double, HEADING_RANGE: Double, headingData: [Double], x: Double, y: Double) -> (Bool, Double) {
        var diffHeading = [Double]()
        for mapHeading in headingData {
            let adjustedHeading = adjustHeading(heading, mapHeading)
            diffHeading.append(abs(adjustedHeading))
        }
        if let minHeading = diffHeading.min() {
            let valid = minHeading < HEADING_RANGE
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
