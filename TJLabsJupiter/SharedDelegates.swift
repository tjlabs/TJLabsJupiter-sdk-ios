
import Foundation
import TJLabsCommon

public class SharedRFDGeneratorDelegate: RFDGeneratorDelegate {
    public  var listeners = [RFDGeneratorDelegate]()

    // Add a listener
    public func addListener(_ listener: RFDGeneratorDelegate) {
        listeners.append(listener)
    }

    // RFDGeneratorDelegate methods
    public func onRfdResult(_ generator: RFDGenerator, receivedForce: ReceivedForce) {
        listeners.forEach { $0.onRfdResult(generator, receivedForce: receivedForce) }
    }

    public func onRfdError(_ generator: RFDGenerator, code: Int, msg: String) {
        listeners.forEach { $0.onRfdError(generator, code: code, msg: msg) }
    }
}

public class SharedUVDGeneratorDelegate: UVDGeneratorDelegate {
    public var listeners = [UVDGeneratorDelegate]()

    // Add a listener
    public func addListener(_ listener: UVDGeneratorDelegate) {
        listeners.append(listener)
    }

    // UVDGeneratorDelegate methods
    public func onUvdResult(_ generator: UVDGenerator, userVelocity: UserVelocity) {
        listeners.forEach { $0.onUvdResult(generator, userVelocity: userVelocity) }
    }

    public func onPressureResult(_ generator: UVDGenerator, hPa: Double) {
        listeners.forEach { $0.onPressureResult(generator, hPa: hPa) }
    }

    public func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        listeners.forEach { $0.onVelocityResult(generator, kmPh: kmPh) }
    }

    public func onUvdPauseMillis(_ generator: UVDGenerator, time: Double) {
        listeners.forEach { $0.onUvdPauseMillis(generator, time: time) }
    }

    public func onUvdError(_ generator: UVDGenerator, error: String) {
        listeners.forEach { $0.onUvdError(generator, error: error) }
    }
}

