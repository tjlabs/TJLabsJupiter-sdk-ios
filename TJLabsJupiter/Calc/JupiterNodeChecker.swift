
import Foundation
import TJLabsCommon

private struct Point {
    var x: Double
    var y: Double
    var direction: Double
}

struct JupiterNodeChecker {
    static var passedNode: Int = -1
    static var passedNodeMatchedIndex = -1
    static var passedNodeCoord: [Double] = [0, 0]
    static var passedNodeHeadings: [Double] = []
    static var currentPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    static var passedNodeInfoBuffer: [PassedNodeInfo] = []
    static var passedNodeInfoBufferForMulti: [PassedNodeInfo] = []
    static var isNeedClearBuffer = false
    static var anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    static var anchorSection = -1
    static var unitDRInfoBuffer: [UserVelocity] = []
    static var isNeedClearUVDBuffer = false

    static var distFromNode: Double = 0
    static var linkCoord: [Double] = [0, 0]
    static var linkDirections: [Double] = []

    static var pathTrajMatchingArea: [[Double]] = []
    static var isInNode = false

    static var buildingLevelChangedCoord: [Double] = []
    static var rqSectionLength: Double = 10

    static func updateAnchorNode(fltResult: FineLocationTrackingOutput, mode: UserMode, sectionNumber: Int) {
        var pathType = 1
        if mode == .MODE_PEDESTRIAN {
            pathType = 0
        }

        let anchorNode = findAnchorNode(fltResult: fltResult, pathType: pathType)
        if anchorNode.nodeNumber != -1 {
            if anchorNode.nodeNumber == self.anchorNode.nodeNumber {
                anchorSection = sectionNumber
            } else {
                self.anchorNode = anchorNode
                anchorSection = sectionNumber
                isNeedClearBuffer = true
                isNeedClearUVDBuffer = true
            }
        }
        print("updateAnchorNode - level: \(fltResult.level_name), x: \(fltResult.x), y: \(fltResult.y), h: \(fltResult.absolute_heading) // anchorNode: \(anchorNode)")
    }

    static func findAnchorNode(fltResult: FineLocationTrackingOutput, pathType: Int) -> PassedNodeInfo {
        let startNodeHeading = passedNodeHeadings
        let nodeInfoBuffer = passedNodeInfoBuffer
        
        var resultPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        
        let startCoord = linkCoord
        let heading = TJLabsUtilFunctions.shared.compensateDegree(fltResult.absolute_heading)
        var diffHeading = [Double]()
        var candidateDirections = [Double]()

        for mapHeading in startNodeHeading {
            var diffValue: Double = 0
            if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                diffValue = abs(heading - (mapHeading+360))
            } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
                diffValue = abs(mapHeading - (heading+360))
            } else {
                diffValue = abs(heading - mapHeading)
            }
            diffHeading.append(diffValue)
            
            let MARGIN: Double = 30
            
            if (diffValue >= 180-MARGIN && diffValue <= 180+MARGIN) {
                candidateDirections.append(mapHeading)
            }
        }
        let sectionLength: Double = 100
        let PIXELS_TO_CHECK = Int(sectionLength)
        
        if (candidateDirections.count == 1) {
            let direction = candidateDirections[0]
            var candidateNodeNumbers = [Int]()
            
            if direction.truncatingRemainder(dividingBy: 90) != 0 {
                let linkDirs = linkDirections
                for item in nodeInfoBuffer.reversed() {
                    var validCount = 0
                    for heading in linkDirs {
                        if item.nodeHeadings.contains(heading) {
                            validCount += 1
                        }
                    }
                    if validCount == linkDirs.count {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
            
            let paddingValues = calculatePaddingByHeading(oppositeHeading: direction, length: sectionLength)
            
            var x: Double = startCoord[0]
            var y: Double = startCoord[1]
            let directionRad = TJLabsUtilFunctions.shared.degree2radian(degree: direction)
            for _ in 0..<PIXELS_TO_CHECK {
                x += cos(directionRad)
                y += sin(directionRad)
                let matchedNodeResult = JupiterPathMatchingCalculator.shared.getMatchedNodeWithCoord(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, fltResult: fltResult, originCoord: startCoord, coordToCheck: [x, y], pathType: pathType, paddingValues: paddingValues)
                if (matchedNodeResult.0) {
                    break
                } else {
                    if (matchedNodeResult.1 != -1) {
                        candidateNodeNumbers.append(matchedNodeResult.1)
                    }
                }
            }
            for nodeNumber in candidateNodeNumbers.reversed() {
                for item in nodeInfoBuffer {
                    if item.nodeNumber == nodeNumber {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
        } else {
            let linkDirs = linkDirections
            for item in nodeInfoBuffer.reversed() {
                var validCount = 0
                for heading in linkDirs {
                    if item.nodeHeadings.contains(heading) {
                        validCount += 1
                    }
                }
                if validCount == linkDirs.count {
                    resultPassedNodeInfo = item
                    return resultPassedNodeInfo
                }
            }
        }
        
        if resultPassedNodeInfo.nodeNumber == -1 {
            if nodeInfoBuffer.isEmpty {
                return resultPassedNodeInfo
            }
            
            let currentNodeCoord = nodeInfoBuffer[nodeInfoBuffer.count-1].nodeCoord
            if startCoord[0] == currentNodeCoord[0] && startCoord[1] == currentNodeCoord[1] {
                return nodeInfoBuffer[nodeInfoBuffer.count-1]
            }
        }
        
        return resultPassedNodeInfo
    }

    static func updateNodeAndLinkInfo(
        uvdIndex: Int,
        currentResult: FineLocationTrackingOutput,
        pastResult: FineLocationTrackingOutput,
        mode: UserMode,
        updateType: UpdateNodeLinkType
    ) {
        let x = currentResult.x
        let y = currentResult.y
        let building = currentResult.building_name
        let level = currentResult.level_name
        let paddingValues = JupiterMode.PADDING_VALUE_LARGE
        
        let pathType = mode == .MODE_VEHICLE ? 1 : 0
        if building.isEmpty || level.isEmpty { return }
        let key = "\(JupiterPathMatchingCalculator.shared.sectorId)_\(building)_\(level)"
        let checkAvailablePathPixelResult = JupiterPathMatchingCalculator.shared.checkIsAvailablePathPixelData(key: key)
        if checkAvailablePathPixelResult.0 {
            let pathPixelData = checkAvailablePathPixelResult.1
            let mainType: [Int] = pathPixelData.roadType
            let mainRoad: [[Double]] = pathPixelData.road
            let mainHeading: [String] = pathPixelData.roadHeading
            let mainNode: [Int] = pathPixelData.nodeNumber

            let roadX = mainRoad[0]
            let roadY = mainRoad[1]
            let xMin = x - paddingValues
            let xMax = x + paddingValues
            let yMin = y - paddingValues
            let yMax = y + paddingValues

            let correctedX = round(x)
            let correctedY = round(y)
            
            if updateType == .STABLE {
                handleStableUpdate(uvdIndex: uvdIndex, currentResult: currentResult, pathType: pathType, roadX: roadX, roadY: roadY, mainType: mainType, mainHeading: mainHeading, mainNode: mainNode)
            } else if updateType == .PATH_TRAJ_MATCHING {
                handlePathTrajectoryMatching(uvdIndex: uvdIndex, currentResult: currentResult, pastResult: pastResult, pathType: pathType, roadX: roadX, roadY: roadY, mainType: mainType, mainHeading: mainHeading, mainNode: mainNode, xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax, correctedX: correctedX, correctedY: correctedY)
            } else {
                handleDefaultUpdate(uvdIndex: uvdIndex, currentResult: currentResult, pastResult: pastResult, pathType: pathType, roadX: roadX, roadY: roadY, mainType: mainType, mainHeading: mainHeading, mainNode: mainNode, xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax, correctedX: correctedX, correctedY: correctedY)
            }
        }
    }
    
    static func handleStableUpdate(
        uvdIndex: Int,
        currentResult: FineLocationTrackingOutput,
        pathType: Int,
        roadX: [Double],
        roadY: [Double],
        mainType: [Int],
        mainHeading: [String],
        mainNode: [Int]
    ) {
        let x: Double = currentResult.x
        let y: Double = currentResult.y
        let linkDir = linkDirections
        let currentResultHeading = currentResult.absolute_heading

        for i in 0..<roadX.count {
            let xPath = roadX[i]
            let yPath = roadY[i]
            let node = mainNode[i]
            let headingArray = mainHeading[i]
            let pathTypeLoaded = mainType[i]
            let isPossibleNode = pathType == 1 ? (pathTypeLoaded != 0 && pathTypeLoaded != 2) : true

            if xPath != x || yPath != y { continue }

            let ppHeadingValues = headingArray.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            let oppositeHeading = calculateOppositeHeading(currentHeading: currentResultHeading, linkDir: linkDir)
            let paddingValues = calculatePaddingByHeading(oppositeHeading: oppositeHeading, length: rqSectionLength)

            var xToCheck = x
            var yToCheck = y

            for p in 0..<Int(rqSectionLength) {
                let oppositeHeadingRad = TJLabsUtilFunctions.shared.compensateDegree(oppositeHeading)
                xToCheck += cos(oppositeHeadingRad)
                yToCheck += sin(oppositeHeadingRad)
                
                let (matched, matchedNode, _) = JupiterPathMatchingCalculator.shared.getMatchedNodeWithCoord(region: JupiterPathMatchingCalculator.shared.region, sectorId: JupiterPathMatchingCalculator.shared.sectorId, fltResult: currentResult, originCoord: [x, y], coordToCheck: [xToCheck, yToCheck], pathType: pathType, paddingValues: paddingValues)

                if matched { break }
                if matchedNode != -1 {
                    let indexScale = (pathType == 1) ? 1 : 2
                    registerPassedNode(
                        node: matchedNode,
                        x: x,
                        y: y,
                        coord: [xPath, yPath],
                        headings: ppHeadingValues,
                        matchedIndex: uvdIndex - ((p + 1) * indexScale),
                        heading: currentResultHeading
                    )
                    break
                }
            }

            linkCoord = [xPath, yPath]
            linkDirections = ppHeadingValues

            if node != 0 && isPossibleNode {
                registerPassedNode(node: node, x: x, y: y, coord: [xPath, yPath], headings: ppHeadingValues, matchedIndex: uvdIndex, heading: currentResultHeading)
                isInNode = true
            } else {
                isInNode = false
            }
        }
    }
    
    static func handlePathTrajectoryMatching(
        uvdIndex: Int,
        currentResult: FineLocationTrackingOutput,
        pastResult: FineLocationTrackingOutput,
        pathType: Int,
        roadX: [Double],
        roadY: [Double],
        mainType: [Int],
        mainHeading: [String],
        mainNode: [Int],
        xMin: Double,
        xMax: Double,
        yMin: Double,
        yMax: Double,
        correctedX: Double,
        correctedY: Double
    ) {
        let x: Double = currentResult.x
        let y: Double = currentResult.y
        var nodeCandidates: [Int] = []
        var xCandidates: [Double] = []
        var yCandidates: [Double] = []
        var headingCandidates: [String] = []
        var localPassedNodeInfoBuffer: [PassedNodeInfo] = []
        let currentResultHeading = Double(currentResult.absolute_heading)
        let pastResultHeading = Double(currentResult.absolute_heading)

        for i in 0..<roadX.count {
            let xPath = roadX[i]
            let yPath = roadY[i]
            let node = mainNode[i]
            let headingArray = mainHeading[i]
            let pathTypeLoaded = mainType[i]
            let isPossibleNode = pathType == 1 ? (pathTypeLoaded != 0 && pathTypeLoaded != 2) : true

            if (xPath >= xMin && xPath <= xMax) && (yPath >= yMin && yPath <= yMax) {
                if node != 0 {
                    nodeCandidates.append(node)
                    xCandidates.append(xPath)
                    yCandidates.append(yPath)
                    headingCandidates.append(headingArray)
                }

                if xPath == correctedX && yPath == correctedY {
                    let ppHeadingValues = headingArray.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    linkCoord = [xPath, yPath]
                    let filtered = ppHeadingValues.filter { !linkDirections.contains($0) }
                    linkDirections = filtered.isEmpty ? ppHeadingValues : filtered

                    if node != 0 && isPossibleNode {
                        isInNode = true
                        let info = PassedNodeInfo(nodeNumber: node, nodeCoord: [xPath, yPath], nodeHeadings: ppHeadingValues, matchedIndex: uvdIndex, userHeading:currentResultHeading)
                        localPassedNodeInfoBuffer.append(info)
                    } else {
                        isInNode = false
                    }
                }
            }
        }

        if (pastResult.x != currentResult.x) || (pastResult.y != currentResult.y) {
            let point1 = Point(x: pastResult.x, y: pastResult.y, direction: pastResultHeading)
            let point2 = Point(x: currentResult.x, y: currentResult.y, direction: currentResultHeading)
            if let intersection = findIntersection(point1: point1, point2: point2) {
                let distances = xCandidates.indices.map { i -> Double in
                    let dx = intersection.x - xCandidates[i]
                    let dy = intersection.y - yCandidates[i]
                    return sqrt(dx * dx + dy * dy)
                }

                if let minValue = distances.min(), let idxMin = distances.firstIndex(of: minValue), minValue <= 20 {
                    let ppHeadingValues = headingCandidates[idxMin].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    let infoToAdd = PassedNodeInfo(
                        nodeNumber: nodeCandidates[idxMin],
                        nodeCoord: [xCandidates[idxMin], yCandidates[idxMin]],
                        nodeHeadings: ppHeadingValues,
                        matchedIndex: uvdIndex,
                        userHeading: currentResultHeading)
                    localPassedNodeInfoBuffer.append(infoToAdd)
                }
            }
        }

        for info in localPassedNodeInfoBuffer.reversed() {
            registerPassedNode(
                node: info.nodeNumber,
                x: x,
                y: y,
                coord: info.nodeCoord,
                headings: info.nodeHeadings,
                matchedIndex: info.matchedIndex,
                heading: info.userHeading
            )
        }
    }
    
    static func handleDefaultUpdate(
        uvdIndex: Int,
        currentResult: FineLocationTrackingOutput,
        pastResult: FineLocationTrackingOutput,
        pathType: Int,
        roadX: [Double],
        roadY: [Double],
        mainType: [Int],
        mainHeading: [String],
        mainNode: [Int],
        xMin: Double,
        xMax: Double,
        yMin: Double,
        yMax: Double,
        correctedX: Double,
        correctedY: Double
    ) {
        let x: Double = currentResult.x
        let y: Double = currentResult.y
        var isNodePassed = false
        var nodeCandidates: [Int] = []
        var xCandidates: [Double] = []
        var yCandidates: [Double] = []
        var headingCandidates: [String] = []
        let currentResultHeading: Double = currentResult.absolute_heading
        let pastResultHeading: Double = currentResult.absolute_heading

        for i in roadX.indices {
            let xPath = roadX[i]
            let yPath = roadY[i]
            let node = mainNode[i]
            let headingArray = mainHeading[i]
            let pathTypeLoaded = mainType[i]
            let isPossibleNode = pathType == 1 ? (pathTypeLoaded != 0 && pathTypeLoaded != 2) : true

            if xPath >= xMin && xPath <= xMax && yPath >= yMin && yPath <= yMax {
                if node != 0 {
                    nodeCandidates.append(node)
                    xCandidates.append(xPath)
                    yCandidates.append(yPath)
                    headingCandidates.append(headingArray)
                }

                if xPath == correctedX && yPath == correctedY {
                    let ppHeadingValues = headingArray.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    linkCoord = [xPath, yPath]
                    linkDirections = ppHeadingValues

                    if node != 0 && isPossibleNode {
                        isInNode = true
                        isNodePassed = true
                        registerPassedNode(node: node, x: x, y: y, coord: [xPath, yPath], headings: ppHeadingValues, matchedIndex: uvdIndex, heading: currentResultHeading)
                    } else {
                        isInNode = false
                    }
                }
            }
        }

        if !isNodePassed && (pastResult.x != currentResult.x) || (pastResult.y != currentResult.y) {
            let point1 = Point(x: pastResult.x, y: pastResult.y, direction: pastResultHeading)
            let point2 = Point(x: currentResult.x, y: currentResult.y, direction: currentResultHeading)
            if let intersection = findIntersection(point1: point1, point2: point2) {
                let distances = xCandidates.indices.map { i in
                    let dx = intersection.x - xCandidates[i]
                    let dy = intersection.y - yCandidates[i]
                    return sqrt(dx * dx + dy * dy)
                }

                if let minValue = distances.min(), let idxMin = distances.firstIndex(of: minValue), minValue <= 20 {
                    let ppHeadingValues = headingCandidates[idxMin].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    linkCoord = [currentResult.x, currentResult.y]
                    linkDirections = ppHeadingValues
                    registerPassedNode(
                        node: nodeCandidates[idxMin],
                        x: x,
                        y: y,
                        coord: [xCandidates[idxMin], yCandidates[idxMin]],
                        headings: ppHeadingValues,
                        matchedIndex: uvdIndex,
                        heading: currentResultHeading
                    )
                }
            }
        }
    }

    static func calculateOppositeHeading(currentHeading: Double, linkDir: [Double]) -> Double {
        var opposite = TJLabsUtilFunctions.shared.compensateDegree(currentHeading - 180)
        var minDiff: Double = 360
        for mapHeading in linkDir {
            let diff: Double
            if currentHeading > 270 && mapHeading < 90 {
                diff = abs(currentHeading - (mapHeading + 360))
            } else if mapHeading > 270 && currentHeading < 90 {
                diff = abs(mapHeading - (currentHeading + 360))
            } else {
                diff = abs(currentHeading - mapHeading)
            }
            
            if (diff < minDiff) {
                minDiff = diff
                opposite = TJLabsUtilFunctions.shared.compensateDegree(mapHeading - 180)
            }
        }
        return opposite
    }
    
    static func calculatePaddingByHeading(oppositeHeading: Double, length: Double) -> [Double] {
        var paddingValues = [Double] (repeating: 20, count: 4)
        if (oppositeHeading == 0) {
            paddingValues = [0, length, 1, 1]
        } else if (oppositeHeading == 90) {
            paddingValues = [1, 1, 0, length]
        } else if (oppositeHeading == 180) {
            paddingValues = [length, 0, 1, 1]
        } else if (oppositeHeading == 270) {
            paddingValues = [1, 1, length, 0]
        } else {
            paddingValues = [length, length, length, length]
        }
        
        return paddingValues
    }
    
    private static func registerPassedNode(node: Int, x: Double, y: Double, coord: [Double], headings: [Double], matchedIndex: Int, heading: Double) {
        passedNode = node
        passedNodeMatchedIndex = matchedIndex
        passedNodeCoord = coord
        passedNodeHeadings = headings
        print("(JupiterNodeChecker) registerPassedNode : passedNode = \(passedNode) // passedNodeMatchedIndex = \(passedNodeMatchedIndex) // passedNodeCoord = \(passedNodeCoord) // passedNodeHeadings = \(passedNodeHeadings)")
        let dx = coord[0] - x
        let dy = coord[1] - y
        distFromNode = sqrt(dx*dx + dy*dy)
        currentPassedNodeInfo = PassedNodeInfo(nodeNumber: node, nodeCoord: coord, nodeHeadings: headings, matchedIndex: matchedIndex, userHeading: heading)
        controlPassedNodeInfo(passedNodeInfo: currentPassedNodeInfo)
        controlPassedNodeInfoForMulti(passedNodeInfo: currentPassedNodeInfo)
    }
    
    private static func controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo) {
        if (self.passedNodeInfoBuffer.count > 1) {
            let currentNode = passedNodeInfo.nodeNumber
            let pastNode = passedNodeInfoBuffer[passedNodeInfoBuffer.count-1].nodeNumber
            
            if (currentNode == pastNode) {
                self.passedNodeInfoBuffer.remove(at: passedNodeInfoBuffer.count-1)
            }
        }
        
        self.passedNodeInfoBuffer.append(passedNodeInfo)
        if (self.passedNodeInfoBuffer.count > 30) {
            self.passedNodeInfoBuffer.remove(at: 0)
        }
        
        if (isNeedClearBuffer) {
            let pastBuffer = self.passedNodeInfoBuffer
            var newBuffer = [PassedNodeInfo]()
            var startIndex: Int = 0
            var isFind: Bool = false
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].nodeNumber == self.anchorNode.nodeNumber {
                    startIndex = i
                    isFind = true
                    break
                }
            }
            
            if (isFind) {
                for i in startIndex..<pastBuffer.count {
                    newBuffer.append(pastBuffer[i])
                }
            } else {
                newBuffer.append(self.anchorNode)
            }
            
            self.passedNodeInfoBuffer = newBuffer
            isNeedClearBuffer = false
        }
    }
    
    private static func controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo) {
        if (self.passedNodeInfoBufferForMulti.count > 1) {
            let currentNode = passedNodeInfo.nodeNumber
            let pastNode = passedNodeInfoBufferForMulti[passedNodeInfoBufferForMulti.count-1].nodeNumber
            
            if (currentNode == pastNode) {
                self.passedNodeInfoBufferForMulti.remove(at: passedNodeInfoBufferForMulti.count-1)
            }
        }
        self.passedNodeInfoBufferForMulti.append(passedNodeInfo)
        if (self.passedNodeInfoBufferForMulti.count > 5) {
            self.passedNodeInfoBufferForMulti.remove(at: 0)
        }
    }
    
    private static func findIntersection(point1: Point, point2: Point) -> Point? {
        let radian1 = TJLabsUtilFunctions.shared.compensateDegree(point1.direction)
        let radian2 = TJLabsUtilFunctions.shared.compensateDegree(point2.direction)

        if radian1 == radian2 {
            return nil
        } else {
            if point1.direction == 90 || point1.direction == 270 {
                return Point(x: point1.x, y: point2.y, direction: -1)
            } else if (point2.direction == 90 || point2.direction == 270) {
                return Point(x: point2.x, y: point1.y, direction: -1)
            } else {
                let slope1 = tan(radian1)
                let slope2 = tan(radian2)
                
                let x = (slope1 * point1.x - slope2 * point2.x + point2.y - point1.y) / (slope1 - slope2)
                let y = slope1 * (x - point1.x) + point1.y
                return Point(x: x, y: y, direction: -1)
            }
        }
    }
}
