//
//  NativeLiquidGlassView.swift
//  Runner
//
//  Created by Pushin' App
//  Native Apple Liquid Glass implementation using UIVisualEffectView
//

import Flutter
import UIKit

public class NativeLiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeLiquidGlassView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

public class NativeLiquidGlassView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var _blurView: UIVisualEffectView
    private var _borderLayer: CALayer

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)

        // Create the authentic Apple liquid glass effect
        let blurEffect: UIBlurEffect
        if let args = args as? [String: Any],
           let useUltraThin = args["useUltraThinMaterial"] as? Bool,
           useUltraThin {
            // Apple's ultra-thin material - closest to system UI
            blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        } else {
            // Regular thin material for navigation elements
            blurEffect = UIBlurEffect(style: .systemThinMaterial)
        }

        _blurView = UIVisualEffectView(effect: blurEffect)
        _blurView.frame = frame
        _blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure corner radius for pill shape
        let borderRadius = (args as? [String: Any])?["borderRadius"] as? Double ?? 32.0
        _blurView.layer.cornerRadius = CGFloat(borderRadius)
        _blurView.clipsToBounds = true

        // Add ultra-thin border like Apple's design
        _borderLayer = CALayer()
        _borderLayer.frame = _blurView.bounds
        _borderLayer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        _borderLayer.borderWidth = 0.5
        _borderLayer.cornerRadius = CGFloat(borderRadius)
        _blurView.layer.addSublayer(_borderLayer)

        _view.addSubview(_blurView)

        super.init()

        // Listen for frame changes to update border
        _view.addObserver(self, forKeyPath: "frame", options: .new, context: nil)
    }

    deinit {
        _view.removeObserver(self, forKeyPath: "frame")
    }

    public func view() -> UIView {
        return _view
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "frame" {
            _borderLayer.frame = _blurView.bounds
        }
    }
}