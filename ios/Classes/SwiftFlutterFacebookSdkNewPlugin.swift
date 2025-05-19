import Flutter
import UIKit
import FBSDKCoreKit

let PLATFORM_CHANNEL = "flutter_facebook_sdk_new/methodChannel"
let EVENTS_CHANNEL = "flutter_facebook_sdk_new/eventChannel"

public class SwiftFlutterFacebookSdkNewPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var _eventSink: FlutterEventSink?
    var deepLinkUrl: String = ""
    var _queuedLinks = [String]()
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        _queuedLinks.forEach({ events($0) })
        _queuedLinks.removeAll()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftFlutterFacebookSdkNewPlugin()
        let channel = FlutterMethodChannel(name: PLATFORM_CHANNEL, binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: EVENTS_CHANNEL, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        Settings.shared.isAdvertiserTrackingEnabled = false
        let launchOptionsForFacebook = launchOptions as? [UIApplication.LaunchOptionsKey: Any]
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptionsForFacebook)
        AppLinkUtility.fetchDeferredAppLink { (url, error) in
            if let error = error {
                print("Error %a", error)
            }
            if let url = url {
                self.deepLinkUrl = url.absoluteString
                self.sendMessageToStream(link: self.deepLinkUrl)
            }
        }
        return true
    }
    
    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        deepLinkUrl = url.absoluteString
        self.sendMessageToStream(link: deepLinkUrl)
        return ApplicationDelegate.shared.application(application, open: url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String, annotation: options[UIApplication.OpenURLOptionsKey.annotation])
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        // AppEvents.shared.activateApp()
    }
    
    func logEvent(contentType: String, contentData: String, contentId: String, currency: String, price: Double, type: String) {
        let parameters = [
            AppEvents.ParameterName.content: contentData,
            AppEvents.ParameterName.contentID: contentId,
            AppEvents.ParameterName.contentType: contentType,
            AppEvents.ParameterName.currency: currency
        ]
        switch type {
        case "addToWishlist":
            AppEvents.shared.logEvent(.addedToWishlist, valueToSum: price, parameters: parameters)
        case "addToCart":
            AppEvents.shared.logEvent(.addedToCart, valueToSum: price, parameters: parameters)
        case "viewContent":
            AppEvents.shared.logEvent(.viewedContent, valueToSum: price, parameters: parameters)
        default:
            break
        }
    }
    
    func logCompleteRegistrationEvent(registrationMethod: String) {
        let parameters = [
            AppEvents.ParameterName.registrationMethod: registrationMethod
        ]
        AppEvents.shared.logEvent(.completedRegistration, parameters: parameters)
    }
    
    func logPurchase(amount: Double, currency: String, parameters: Dictionary<String, Any>) {
        AppEvents.shared.logPurchase(amount: amount, currency: currency)
    }
    
    func logSearchEvent(contentType: String, contentData: String, contentId: String, searchString: String, success: Bool) {
        let parameters = [
            AppEvents.ParameterName.contentType: contentType,
            AppEvents.ParameterName.content: contentData,
            AppEvents.ParameterName.contentID: contentId,
            AppEvents.ParameterName.searchString: searchString,
            AppEvents.ParameterName.success: NSNumber(value: success ? 1 : 0)
        ] as [AppEvents.ParameterName: Any]
        
        AppEvents.shared.logEvent(.searched, parameters: parameters)
    }
    
    func logInitiateCheckoutEvent(contentData: String, contentId: String, contentType: String, numItems: Int, paymentInfoAvailable: Bool, currency: String, totalPrice: Double) {
        let parameters = [
            AppEvents.ParameterName.content: contentData,
            AppEvents.ParameterName.contentID: contentId,
            AppEvents.ParameterName.contentType: contentType,
            AppEvents.ParameterName.numItems: NSNumber(value: numItems),
            AppEvents.ParameterName.paymentInfoAvailable: NSNumber(value: paymentInfoAvailable ? 1 : 0),
            AppEvents.ParameterName.currency: currency
        ] as [AppEvents.ParameterName: Any]
        
        AppEvents.shared.logEvent(.initiatedCheckout, valueToSum: totalPrice, parameters: parameters)
    }
    
    func logGenericEvent(args: Dictionary<String, Any>) {
        let eventName = args["eventName"] as! String
        let valueToSum = args["valueToSum"] as? Double
        let parameters = args["parameters"] as? Dictionary<AppEvents.ParameterName, Any>
        if valueToSum != nil && parameters != nil {
            AppEvents.shared.logEvent(AppEvents.Name(eventName), valueToSum: valueToSum!, parameters: parameters!)
        } else if parameters != nil {
            AppEvents.shared.logEvent(AppEvents.Name(eventName), parameters: parameters!)
        } else if valueToSum != nil {
            AppEvents.shared.logEvent(AppEvents.Name(eventName), valueToSum: valueToSum!)
        } else {
            AppEvents.shared.logEvent(AppEvents.Name(eventName))
        }
    }
    
    func sendMessageToStream(link: String) {
        guard let eventSink = _eventSink else {
            _queuedLinks.append(link)
            return
        }
        eventSink(link)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeSDK":
            ApplicationDelegate.shared.initializeSDK()
            result(nil)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getDeepLinkUrl":
            result(deepLinkUrl)
        case "logViewedContent", "logAddToCart", "logAddToWishlist":
            guard let myArgs = call.arguments as? [String: Any],
                  let contentType = myArgs["contentType"] as? String,
                  let contentData = myArgs["contentData"] as? String,
                  let contentId = myArgs["contentId"] as? String,
                  let currency = myArgs["currency"] as? String,
                  let price = myArgs["price"] as? Double else {
                result(FlutterError(code: "-1", message: "Invalid arguments", details: nil))
                return
            }
            let type = call.method.replacingOccurrences(of: "log", with: "").lowercased()
            self.logEvent(contentType: contentType, contentData: contentData, contentId: contentId, currency: currency, price: price, type: type)
            result(true)
        case "activateApp":
            AppEvents.shared.activateApp()
            result(true)
        case "logCompleteRegistration":
            guard let myArgs = call.arguments as? [String: Any],
                  let registrationMethod = myArgs["registrationMethod"] as? String else {
                result(false)
                return
            }
            self.logCompleteRegistrationEvent(registrationMethod: registrationMethod)
            result(true)
        case "logPurchase":
            guard let myArgs = call.arguments as? [String: Any],
                  let amount = myArgs["amount"] as? Double,
                  let currency = myArgs["currency"] as? String,
                  let parameters = myArgs["parameters"] as? Dictionary<String, Any> else {
                result(false)
                return
            }
            self.logPurchase(amount: amount, currency: currency, parameters: parameters)
            result(true)
        case "logSearch":
            guard let myArgs = call.arguments as? [String: Any],
                  let contentType = myArgs["contentType"] as? String,
                  let contentData = myArgs["contentData"] as? String,
                  let contentId = myArgs["contentId"] as? String,
                  let searchString = myArgs["searchString"] as? String,
                  let success = myArgs["success"] as? Bool else {
                result(false)
                return
            }
            self.logSearchEvent(contentType: contentType, contentData: contentData, contentId: contentId, searchString: searchString, success: success)
            result(true)
        case "logInitiateCheckout":
            guard let myArgs = call.arguments as? [String: Any],
                  let contentType = myArgs["contentType"] as? String,
                  let contentData = myArgs["contentData"] as? String,
                  let contentId = myArgs["contentId"] as? String,
                  let numItems = myArgs["numItems"] as? Int,
                  let paymentInfoAvailable = myArgs["paymentInfoAvailable"] as? Bool,
                  let currency = myArgs["currency"] as? String,
                  let totalPrice = myArgs["totalPrice"] as? Double else {
                result(false)
                return
            }
            self.logInitiateCheckoutEvent(contentData: contentData, contentId: contentId, contentType: contentType, numItems: numItems, paymentInfoAvailable: paymentInfoAvailable, currency: currency, totalPrice: totalPrice)
            result(true)
        case "setAdvertiserTracking":
            guard let myArgs = call.arguments as? [String: Any],
                  let enabled = myArgs["enabled"] as? Bool else {
                result(false)
                return
            }
            Settings.shared.isAdvertiserTrackingEnabled = enabled
            result(enabled)
        case "logEvent":
            guard let myArgs = call.arguments as? [String: Any] else {
                result(false)
                return
            }
            logGenericEvent(args: myArgs)
            result(true)
        case "logRated":
            AppEvents.shared.logEvent(.rated)
            result(true)
        case "logDonate":
            AppEvents.shared.logEvent(.donate)
            result(true)
        case "logContact":
            AppEvents.shared.logEvent(.contact)
            result(true)
        case "logStartTrial":
            AppEvents.shared.logEvent(.startTrial)
            result(true)
        case "logSpentCredits":
            AppEvents.shared.logEvent(.spentCredits)
            result(true)
        case "logSubscribe":
            AppEvents.shared.logEvent(.subscribe)
            result(true)
        case "logPurchased":
            AppEvents.shared.logEvent(.purchased)
            result(true)
        case "logCustomizeProduct":
            AppEvents.shared.logEvent(.customizeProduct)
            result(true)
        case "logAchievedLevel":
            AppEvents.shared.logEvent(.achievedLevel)
            result(true)
        case "logFindLocation":
            AppEvents.shared.logEvent(.findLocation)
            result(true)
        case "logAddedToCart":
            AppEvents.shared.logEvent(.addedToCart)
            result(true)
        case "logSchedule":
            AppEvents.shared.logEvent(.schedule)
            result(true)
        case "logSubmitApplication":
            AppEvents.shared.logEvent(.submitApplication)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
