//
//  Event.swift
//  IRCClient
//
//  Created by Alexander Rogachev on 5/7/18.
//  Copyright © 2018 Alexander Rogachev. All rights reserved.
//

import Foundation

public extension IRC {
    
    /// Wrapping structure for mode change pair values
    public struct ModeChange {
        
        /// Target of the mode change.
        public let who: String
        
        /// Mode change value.
        public let mode: String
    }
    
    /// Known IRC events.
    public enum Event {
        
        /// Network error.
        case error(error: Error?)
        
        /// Connected to server.
        case connect
        
        /// Disconnected from server.
        case disconnect
        
        /// Ping message.
        case ping(from: String, value: String)
        
        /// Welcome (001) message.
        case welcome(from: String, message: String?)
        
        /// Message of the day (partial) string.
        case messageOfTheDay(from: String, message: String)
        
        /// Uptime string.
        case uptime(from: String, value: String)
        
        /// 'Your host' response string.
        case yourHost(from: String, value: String)
        
        /// Server info string.
        case serverInfo(from: String, message: String)
        
        /// Info string.
        case info(from: String, message: String)
        
        /// Supported commands.
        case iSupport(from: String, commands: [String], comment: String)
        
        /// Bounce message.
        case bounce(from: String, message: String)
        
        /// User-client response.
        case userClient(from: String, message: String)
        
        /// Operators statistics.
        case userOperators(from: String, count: Int, comment: String)
        
        /// Unknown connections statistics.
        case userUnknownConnections(from: String, count: Int, comment: String)
        
        /// Channels statistics.
        case userChannels(from: String, count: Int, comment: String)
        
        /// Local users statistics.
        case userLocalUsers(from: String, count: Int?, max: Int?, comment: String)
        
        /// Global users statistics.
        case userGlobalUsers(from: String, count: Int?, max: Int?, comment: String)
        
        /// Server info message.
        case userMe(from: String, message: String)
        
        /// Stats string.
        case stats(from: String, message: String)
        
        /// Version request.
        case version(from: String)
        
        /// Private message.
        case privateMessage(user: String, recipient: String, message: String)
        
        /// Notice message.
        case notice(user: String, recipient: String, message: String)
        
        /// Channel join event.
        case channelJoin(user: String, channel: String)
        
        /// Channel part event.
        case channelPart(user: String, channel: String)
        
        /// Capabilities acknowledged event.
        case capabilitiesAcknowledged(capabilities: [String])
        
        /// Capabilities rejected event.
        case capabilitiesRejected(capabilities: [String])
        
        /// Capabilities requested event.
        case capabilitiesRequested(capabilities: [String])
        
        /// Capabilities list response.
        case capabilitiesList(capabilities: [String])
        
        /// Active capabilities list response.
        case capabilitiesActive(capabilities: [String])
        
        /// Mode change.
        case mode(from: String, changes: [ModeChange])
        
        /// IRC error reply.
        case errorReply(from: String, code: String, message: String)
        
        /// Names reply.
        case names(modifier: String, channel: String, users: [String])
        
        /// Unknown event.
        case unknown(message: IRC.Message)
    }
}
