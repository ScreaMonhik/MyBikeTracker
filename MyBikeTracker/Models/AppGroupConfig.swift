//
//  AppGroupConfig.swift
//  MyBikeTracker
//
//  ⚠️ Add this file to BOTH targets: MyBikeTracker + BikeTrackerWidget
//  ⚠️ Replace the ID below with your real App Group identifier from Xcode
//

import Foundation

enum AppGroup {
    /// Shared by the iPhone app and widget. The bundle IDs use `dimsun.*`; this
    /// existing App Group ID is kept so widgets and live-ride checkpoints keep working.
    static let id = "group.com.sunko.mybiketracker"

    /// UserDefaults key for the widget ride data array.
    static let widgetRidesKey = "widget_rides"

}
