//
//  DateFormatter+Extensions.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/3/22.
//

import Foundation

extension DateFormatter {
    static var postFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

extension Date {
    /// Returns a relative time string like "1 min ago", "2 hours ago", "Yesterday".
    var relativeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        if interval < 60 { return "Just now" }
        if interval < 120 { return "1 min ago" }
        if interval < 3600 { return "\(Int(interval / 60)) mins ago" }
        if interval < 7200 { return "1 hour ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hours ago" }
        if interval < 172800 { return "Yesterday" }
        if interval < 604800 { return "\(Int(interval / 86400)) days ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
