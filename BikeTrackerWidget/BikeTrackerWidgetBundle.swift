//
//  BikeTrackerWidgetBundle.swift
//  BikeTrackerWidget
//
//  Created by Dima Sunko on 06.03.2026.
//

import WidgetKit
import SwiftUI

@main
struct BikeTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        YearlyKmWidget()
        YearlyKmCalendarWidget()
        BikeTrackerWidgetControl()
        BikeTrackerLiveActivity()
    }
}
