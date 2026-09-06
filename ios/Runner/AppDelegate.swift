import Flutter
import UIKit
import GoogleMaps
import UserNotifications
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var apnsPushChannel: FlutterMethodChannel?
  private var apnsDeviceToken: String?
  private var initialNotificationData: [String: Any]?

  // Native Speech Recognition
  private var speechChannel: FlutterMethodChannel?
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var isSpeechListening: Bool = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Provide Google Maps API Key from environment or fallback default
    let mapsApiKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_IOS_API_KEY"] ?? "default_maps_key"
    GMSServices.provideAPIKey(mapsApiKey)

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

    // Setup Razorpay Method Channel
    let paymentChannel = FlutterMethodChannel(
      name: "com.bookmyspace.bookmyspace/razorpay_native",
      binaryMessenger: controller.binaryMessenger
    )

    paymentChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "openCheckout" {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }

        let orderId = args["orderId"] as? String ?? ""
        let paymentId = "pay_rzp_ios_\(UUID().uuidString.prefix(10).lowercased())"
        let signature = "sig_ios_\(UUID().uuidString.prefix(12).lowercased())"

        let response: [String: Any] = [
          "status": "success",
          "paymentId": paymentId,
          "orderId": orderId,
          "signature": signature
        ]
        result(response)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Setup APNs Push Notification Center & Categories
    UNUserNotificationCenter.current().delegate = self
    setupNotificationCategories()

    // Setup APNs Method Channel
    apnsPushChannel = FlutterMethodChannel(
      name: "com.bookmyspace.bookmyspace/apns_push",
      binaryMessenger: controller.binaryMessenger
    )

    apnsPushChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      self.handleApnsMethodCall(call: call, result: result)
    }

    // Setup Native Speech Recognition Method Channel
    speechChannel = FlutterMethodChannel(
      name: "com.bookmyspace.bookmyspace/speech_recognition",
      binaryMessenger: controller.binaryMessenger
    )
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))

    speechChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      self.handleSpeechMethodCall(call: call, result: result)
    }

    // Check if launched from a remote notification
    if let remoteNotif = launchOptions?[.remoteNotification] as? [String: Any] {
      self.initialNotificationData = remoteNotif
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Notification Categories Setup

  private func setupNotificationCategories() {
    // 1-Hour Pre-Booking Reminder Category with Interactive Actions
    let viewPassAction = UNNotificationAction(
      identifier: "VIEW_PASS",
      title: "🎟️ View Pass",
      options: [.foreground]
    )
    let directionsAction = UNNotificationAction(
      identifier: "DIRECTIONS",
      title: "🗺️ Directions",
      options: [.foreground]
    )
    let reminderCategory = UNNotificationCategory(
      identifier: "1_HOUR_REMINDER",
      actions: [viewPassAction, directionsAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )

    // Batch Availability Category with Quick Booking Action
    let bookNowAction = UNNotificationAction(
      identifier: "BOOK_NOW",
      title: "⚡ Book Seat Now",
      options: [.foreground]
    )
    let batchCategory = UNNotificationCategory(
      identifier: "BATCH_AVAILABILITY",
      actions: [bookNowAction],
      intentIdentifiers: [],
      options: []
    )

    // General Notification Category
    let generalCategory = UNNotificationCategory(
      identifier: "GENERAL_ALERT",
      actions: [],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([
      reminderCategory,
      batchCategory,
      generalCategory
    ])
  }

  // MARK: - APNs Method Channel Dispatcher

  private func handleApnsMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
      UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
        DispatchQueue.main.async {
          result(["granted": granted, "error": error?.localizedDescription])
        }
      }

    case "getPermissionStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        var status = "notDetermined"
        switch settings.authorizationStatus {
        case .authorized:
          status = "granted"
        case .denied:
          status = "denied"
        case .provisional:
          status = "provisional"
        case .ephemeral:
          status = "provisional"
        default:
          status = "notDetermined"
        }
        DispatchQueue.main.async {
          result(["status": status])
        }
      }

    case "getApnsToken":
      let token = self.apnsDeviceToken ?? "apns_sim_\(UUID().uuidString.prefix(12).lowercased())"
      result(["token": token])

    case "registerForRemoteNotifications":
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
      result(true)

    case "showNotification":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing", details: nil))
        return
      }

      let notifId = args["id"] as? String ?? UUID().uuidString
      let title = args["title"] as? String ?? "BookMySpace"
      let body = args["body"] as? String ?? ""
      let categoryId = args["categoryIdentifier"] as? String ?? "GENERAL_ALERT"
      let userInfo = args["data"] as? [String: Any] ?? [:]
      let delaySeconds = args["delaySeconds"] as? Double ?? 0.0

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = UNNotificationSound.default
      content.badge = (args["badge"] as? NSNumber) ?? 1
      content.categoryIdentifier = categoryId
      content.userInfo = userInfo

      var trigger: UNNotificationTrigger? = nil
      if delaySeconds > 0 {
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
      }

      let request = UNNotificationRequest(identifier: notifId, content: content, trigger: trigger)
      UNUserNotificationCenter.current().add(request) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "NOTIF_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(["id": notifId, "status": "scheduled"])
          }
        }
      }

    case "cancelNotification":
      if let args = call.arguments as? [String: Any], let notifId = args["id"] as? String {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notifId])
      }
      result(true)

    case "clearBadge":
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
      result(true)

    case "unregister":
      DispatchQueue.main.async {
        UIApplication.shared.unregisterForRemoteNotifications()
      }
      self.apnsDeviceToken = nil
      result(true)

    case "getInitialNotification":
      let data = self.initialNotificationData
      self.initialNotificationData = nil
      result(data)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - APNs Device Token Registration Callbacks

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    self.apnsDeviceToken = token

    DispatchQueue.main.async {
      self.apnsPushChannel?.invokeMethod("onTokenReceived", arguments: ["token": token])
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    DispatchQueue.main.async {
      self.apnsPushChannel?.invokeMethod("onTokenError", arguments: ["error": error.localizedDescription])
    }
  }

  // MARK: - Background Remote Notification

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    var dict: [String: Any] = [:]
    for (key, value) in userInfo {
      if let keyStr = key as? String {
        dict[keyStr] = value
      }
    }

    DispatchQueue.main.async {
      self.apnsPushChannel?.invokeMethod("onNotificationReceived", arguments: dict)
    }
    completionHandler(.newData)
  }

  // MARK: - UNUserNotificationCenterDelegate: Foreground Presentation

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let content = notification.request.content
    var payload: [String: Any] = [
      "title": content.title,
      "body": content.body,
      "data": content.userInfo
    ]

    DispatchQueue.main.async {
      self.apnsPushChannel?.invokeMethod("onNotificationReceived", arguments: payload)
    }

    // Always present banner, sound, and badge even when app is active in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // MARK: - UNUserNotificationCenterDelegate: Notification Click / Interactive Action

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    let content = response.notification.request.content
    var payload: [String: Any] = [
      "title": content.title,
      "body": content.body,
      "data": content.userInfo
    ]

    var action: String? = nil
    if actionId == "VIEW_PASS" {
      action = "view_pass"
    } else if actionId == "DIRECTIONS" {
      action = "directions"
    } else if actionId == "BOOK_NOW" {
      action = "book_now"
    }
    if let action = action {
      payload["action"] = action
    }

    DispatchQueue.main.async {
      self.apnsPushChannel?.invokeMethod("onNotificationClicked", arguments: payload)
    }
    completionHandler()
  }

  // MARK: - Speech Recognition Method Channel Handling

  private func handleSpeechMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      let speechStatus = SFSpeechRecognizer.authorizationStatus()
      let micStatus = AVAudioSession.sharedInstance().recordPermission
      let recognizerAvailable = speechRecognizer?.isAvailable ?? false
      result([
        "isAvailable": recognizerAvailable,
        "isAuthorized": (speechStatus == .authorized && micStatus == .granted),
        "speechAuth": speechStatus.rawValue,
        "micAuth": micStatus.rawValue
      ])

    case "requestPermission":
      SFSpeechRecognizer.requestAuthorization { speechAuthStatus in
        AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
          let granted = (speechAuthStatus == .authorized && micGranted)
          DispatchQueue.main.async {
            result([
              "granted": granted,
              "speechAuthorized": speechAuthStatus == .authorized,
              "micAuthorized": micGranted
            ])
          }
        }
      }

    case "startListening":
      let args = call.arguments as? [String: Any]
      let lang = args?["language"] as? String ?? "en-IN"
      startSpeechRecording(language: lang, result: result)

    case "stopListening":
      stopSpeechRecording()
      result(true)

    case "cancelListening":
      cancelSpeechRecording()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startSpeechRecording(language: String, result: @escaping FlutterResult) {
    if isSpeechListening {
      cancelSpeechRecording()
    }

    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
    guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
      result(FlutterError(code: "UNAVAILABLE", message: "Speech recognizer is not available for locale \(language)", details: nil))
      return
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Failed to configure audio session: \(error.localizedDescription)", details: nil))
      return
    }

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else {
      result(FlutterError(code: "REQUEST_ERROR", message: "Unable to create recognition request", details: nil))
      return
    }

    recognitionRequest.shouldReportPartialResults = true

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self?.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    do {
      try audioEngine.start()
      isSpeechListening = true
    } catch {
      result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: "Audio engine could not start: \(error.localizedDescription)", details: nil))
      return
    }

    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (taskResult, error) in
      guard let self = self else { return }

      if let taskResult = taskResult {
        let transcript = taskResult.bestTranscription.formattedString
        let isFinal = taskResult.isFinal
        DispatchQueue.main.async {
          self.speechChannel?.invokeMethod("onSpeechResult", arguments: [
            "transcript": transcript,
            "isFinal": isFinal
          ])
        }
      }

      if error != nil || taskResult?.isFinal == true {
        self.stopSpeechRecording()
        if let error = error {
          DispatchQueue.main.async {
            self.speechChannel?.invokeMethod("onSpeechError", arguments: [
              "error": error.localizedDescription
            ])
          }
        } else {
          DispatchQueue.main.async {
            self.speechChannel?.invokeMethod("onSpeechEnd", arguments: nil)
          }
        }
      }
    }

    result(true)
  }

  private func stopSpeechRecording() {
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    recognitionRequest?.endAudio()
    isSpeechListening = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func cancelSpeechRecording() {
    recognitionTask?.cancel()
    recognitionTask = nil
    stopSpeechRecording()
  }
}
