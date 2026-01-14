//
//  UnlockTimerWidgetBundle.swift
//  UnlockTimerWidget
//
//  Created by King Ezeoffia on 06.01.26.
//

import WidgetKit
import SwiftUI

@main
struct UnlockTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            UnlockTimerWidgetLiveActivity()
        }
    }
}
