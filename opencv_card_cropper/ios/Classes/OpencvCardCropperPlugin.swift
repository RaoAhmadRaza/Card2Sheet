import Flutter
import UIKit

public class OpencvCardCropperPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "opencv_card_cropper", binaryMessenger: registrar.messenger())
    let instance = OpencvCardCropperPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "deskewCard":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "ARG", message: "Missing args", details: nil))
        return
      }
      let imagePath = (args["imagePath"] as? String) ?? (args["path"] as? String)
      guard let imagePath, !imagePath.isEmpty else {
        result(FlutterError(code: "ARG", message: "imagePath is required", details: nil))
        return
      }
      let roi = args["roi"] as? [String: Any]
      let x = roi?["x"] as? NSNumber
      let y = roi?["y"] as? NSNumber
      let w = roi?["width"] as? NSNumber
      let h = roi?["height"] as? NSNumber
      // Call into Objective-C++ implementation
      let outPath = CardDeskewer.deskewAtPath(imagePath, x: x, y: y, width: w, height: h)
      result(outPath)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
