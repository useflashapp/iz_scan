import Flutter
import UIKit
import CardScan

public class IzScanPlugin: NSObject, FlutterPlugin, SimpleScanDelegate {
    
    private var scanResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "iz_scan", binaryMessenger: registrar.messenger())
        let instance = IzScanPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configureCardScan":
            if let arguments = call.arguments as? [String: Any], let apiKey = arguments["apiKey"] as? String {
                configureCardScan(apiKey: apiKey)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
            }
        case "startCardScan":
            startCardScan(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func configureCardScan(apiKey: String) {
        ScanViewController.configure(apiKey: apiKey)
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
               let root = window.rootViewController {
                var top = root
                while let presented = top.presentedViewController {
                    top = presented
                }
                return top
            }
        }

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
           let root = window.rootViewController {
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        return nil
    }

    private func startCardScan(result: @escaping FlutterResult) {
        scanResult = result

        let presentScan: () -> Void = { [weak self] in
            guard let self = self else { return }
            guard let presenter = self.topViewController() else {
                self.scanResult?(FlutterError(
                    code: "NO_VIEW_CONTROLLER",
                    message: "No view controller available to present card scan",
                    details: nil
                ))
                self.scanResult = nil
                return
            }

            let vc = CustomSimpleScanViewController()
            vc.modalPresentationStyle = .fullScreen
            vc.delegate = self
            presenter.present(vc, animated: true)
        }

        if Thread.isMainThread {
            presentScan()
        } else {
            DispatchQueue.main.async(execute: presentScan)
        }
    }

    // MARK: - SimpleScanDelegate methods
    
    public func userDidCancelSimple(_ scanViewController: SimpleScanViewController) {
        scanViewController.dismiss(animated: true)
        scanResult?(nil)
        scanResult = nil
    }
    
    public func userDidScanCardSimple(_ scanViewController: SimpleScanViewController, creditCard: CreditCard) {
        let number = creditCard.number
        let expiryMonth = creditCard.expiryMonth
        let expiryYear = creditCard.expiryYear
        let cardholderName = creditCard.name

        let cardInfo = [
            "number": number,
            "expiryDate": expiryYear,
            "expiryMonth": expiryMonth,
            "cardholderName": cardholderName,
        ]

        scanResult?(cardInfo)
        scanViewController.dismiss(animated: true)
        scanResult = nil
    }
}