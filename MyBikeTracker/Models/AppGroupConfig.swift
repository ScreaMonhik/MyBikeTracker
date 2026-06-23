//
//  AppGroupConfig.swift
//  MyBikeTracker
//
//  ⚠️ Add this file to BOTH targets: MyBikeTracker + BikeTrackerWidget
//  ⚠️ Replace the ID below with your real App Group identifier from Xcode
//

import Foundation

enum AppGroup {
    /// The App Group container identifier shared by the main app and all extensions.
    static let id = "group.com.sunko.mybiketracker"

    /// UserDefaults key for the widget ride data array.
    static let widgetRidesKey = "widget_rides"
}
