import Flutter
import UIKit
import DeviceActivity
import SwiftUI

/// Factory for creating the native Screen Time Report view
class ScreenTimeReportFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ScreenTimeReportView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// The Native View that hosts the DeviceActivityReport
class ScreenTimeReportView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        super.init()

        if #available(iOS 16.0, *) {
            setupReportView()
        } else {
            // Fallback for older iOS versions or just empty view
            let label = UILabel(frame: _view.bounds)
            label.text = "Requires iOS 16.0+"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 10)
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            _view.addSubview(label)
        }
    }

    func view() -> UIView {
        return _view
    }

    @available(iOS 16.0, *)
    private func setupReportView() {
        // Create the context that matches the extension's context
        let context = DeviceActivityReport.Context(rawValue: "Total Activity")
        
        // Explicitly define a broad filter to ensure the extension runs
        // Note: passing empty sets for apps/cats/domains means "include all"
        let filter = DeviceActivityFilter(
            segment: .daily(during: Calendar.current.dateInterval(of: .day, for: Date())!),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: [],
            categories: [],
            webDomains: []
        )
        
        // Create the SwiftUI view with explicit filter
        let reportView = DeviceActivityReport(context, filter: filter)
        
        // Host it in a UIHostingController
        let controller = UIHostingController(rootView: reportView)
        
        // Add to view hierarchy
        controller.view.frame = _view.bounds
        controller.view.autoresizingMask = UIView.AutoresizingMask([.flexibleWidth, .flexibleHeight])
        controller.view.backgroundColor = UIColor.clear
        
        _view.addSubview(controller.view)
        
        // We act as a "trigger" so we don't strictly need to do anything complex here.
        // The mere presence of DeviceActivityReport with the correct context
        // causes the extension to wake up and run makeConfiguration().
    }
}
