//
//  NotificationExtensions.swift
//  Shwordle
//
//  Created by Administrator on 2025-03-02.
//

import Foundation

extension Notification.Name {
    static let didReceiveGameUpdateNotification = Notification.Name("DidReceiveGameUpdateNotification")
    static let authenticationStateChanged = Notification.Name("AuthenticationStateChanged")
}
