//
//  Controller.swift
//  IRCClient
//
//  Created by Alexander Rogachev on 5/7/18.
//  Copyright © 2018 Alexander Rogachev. All rights reserved.
//

import Foundation

/// Delegate protocol for controller.
public protocol IRCControllerDelegate {
    
    /// Called when new event arrives.
    ///
    /// - parameter event: Incoming event.
    func onEvent(_ event: IRC.Event)
}

public extension IRC {
    
    /// A simple mediator between IRC.Client and your application.
    /// Parses incoming messages and transforms them into easy-to-handle
    /// IRC.Event objects. You can use this as an example or a tamplate for your own
    /// IRC.Client message handlers.
    public class Controller {
        
        /// Client instance used to get data from.
        public var client: IRC.Client
        
        /// Delegate object to pass Event callbacks.
        public var delegate: IRCControllerDelegate?
        
        /// Flag indicating whether controller should automatically respond to PING events.
        public var keepAlive: Bool = true
        
        public init(client: IRC.Client) {
            self.client = client
            client.delegate = self
        }
    }
}

extension IRC.Controller: IRCClientDelegate {
    public func onConnected(client: IRC.Client) {
        delegate?.onEvent(IRC.Event.connect)
    }
    
    public func onDisconnected(client: IRC.Client) {
        delegate?.onEvent(IRC.Event.disconnect)
    }
    
    public func onError(client: IRC.Client, error: Error?) {
        delegate?.onEvent(IRC.Event.error(error: error))
    }
    
    public func onMessage(client: IRC.Client, message: IRC.Message) {
        switch message.name.uppercased() {
        case "PING":
            if (keepAlive) {
                client.send(message: IRC.Message.pong(value: message.params.first))
            } else if let from = message.prefix, let value = message.params.first {
                delegate?.onEvent(IRC.Event.ping(from: from, value: value))
            }
        case "VERSION":
            if let from = message.prefix {
                delegate?.onEvent(IRC.Event.version(from: from))
            }
        case "001":
            delegate?.onEvent(IRC.Event.welcome(from: message.prefix!, message: message.params.first))
        case "002":
            if let text = message.params.last, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.yourHost(from: prefix, value: text))
            }
        case "003":
            if let text = message.params.last, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.uptime(from: prefix, value: text))
            }
        case "004":
            if message.params.dropFirst().count > 0, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.serverInfo(from: prefix, message: message.params.dropFirst().joined(separator: " ")))
            }
        case "010":
            if let text = message.params.last, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.bounce(from: prefix, message: text))
            }
        case "005":
            if message.params.dropFirst().count >= 3, let prefix = message.prefix {
                let commands = Array(message.params.dropFirst().dropLast())
                let comment = message.params[message.params.count - 1]
                delegate?.onEvent(IRC.Event.iSupport(from: prefix, commands: commands, comment: comment))
            }
        case "371":
            if let text = message.params.last, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.info(from: prefix, message: text))
            }
        case "372", "375":
            if let text = message.params.last, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.messageOfTheDay(from: prefix, message: text))
            }
        case "374", "376", "366":
            // Ignore "end of" events.
            break
        case "251":
            if message.params.dropFirst().count > 0, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.userClient(from: prefix, message: message.params.dropFirst().joined(separator: " ")))
            }
        case "252":
            if message.params.dropFirst().count == 3, let prefix = message.prefix, let count = Int(message.params[1]) {
                let comment = message.params[2]
                delegate?.onEvent(IRC.Event.userOperators(from: prefix, count: count, comment: comment))
            }
        case "253":
            if message.params.dropFirst().count == 3, let prefix = message.prefix, let count = Int(message.params[1]) {
                let comment = message.params[2]
                delegate?.onEvent(IRC.Event.userUnknownConnections(from: prefix, count: count, comment: comment))
            }
        case "254":
            guard let prefix = message.prefix else {
                break
            }
            
            if message.params.dropFirst().count == 3, let count = Int(message.params[1]) {
                let comment = message.params[2]
                delegate?.onEvent(IRC.Event.userChannels(from: prefix, count: count, comment: comment))
            } else {
                let text = message.params.dropFirst().joined(separator: " ")
                delegate?.onEvent(IRC.Event.userLocalUsers(from: prefix, count: nil, max: nil, comment: text))
            }
        case "255":
            if message.params.dropFirst().count == 4, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.userMe(from: prefix, message: message.params.dropFirst().joined(separator: " ")))
            }
        case "265":
            guard let prefix = message.prefix else {
                break
            }
            
            if message.params.dropFirst().count == 4, let count = Int(message.params[1]), let max = Int(message.params[2]) {
                let comment = message.params[3]
                delegate?.onEvent(IRC.Event.userLocalUsers(from: prefix, count: count, max: max, comment: comment))
            } else {
                let text = message.params.dropFirst().joined(separator: " ")
                delegate?.onEvent(IRC.Event.userLocalUsers(from: prefix, count: nil, max: nil, comment: text))
            }
        case "266":
            guard let prefix = message.prefix else {
                break
            }
            
            if message.params.dropFirst().count == 4, let count = Int(message.params[1]), let max = Int(message.params[2]) {
                let comment = message.params[3]
                delegate?.onEvent(IRC.Event.userGlobalUsers(from: prefix, count: count, max: max, comment: comment))
            } else {
                let text = message.params.dropFirst().joined(separator: " ")
                delegate?.onEvent(IRC.Event.userGlobalUsers(from: prefix, count: nil, max: nil, comment: text))
            }
        case "213", "214", "215", "216", "217", "218", "240", "241", "244", "247", "250":
            if message.params.dropFirst().count > 0, let prefix = message.prefix {
                delegate?.onEvent(IRC.Event.stats(from: prefix, message: message.params.dropFirst().joined(separator: " ")))
            }
        case "353":
            if message.params.count > 3 {
                let modifier = message.params[1]
                let channel = message.params[2]
                let list = message.params[3].components(separatedBy: " ")
                delegate?.onEvent(IRC.Event.names(modifier: modifier, channel: channel, users: list))
            }
        case "MODE":
            if let prefix = message.prefix, message.params.count > 1 {
                let changes = stride(from: 1, through: message.params.count - 2, by: 2).map {
                    return IRC.ModeChange(who: message.params[$0], mode: message.params[$0+1])
                }
                delegate?.onEvent(IRC.Event.mode(from: prefix, changes: changes))
            }
        case "JOIN":
            if let prefix = message.prefix, let channel = message.params.first {
                delegate?.onEvent(IRC.Event.channelJoin(user: prefix, channel: channel))
            }
        case "PART":
            if let prefix = message.prefix, let channel = message.params.first {
                delegate?.onEvent(IRC.Event.channelPart(user: prefix, channel: channel))
            }
        case "CAP":
            if let subcommand = message.params.dropFirst().first {
                switch subcommand {
                case "ACK":
                    delegate?.onEvent(IRC.Event.capabilitiesAcknowledged(capabilities: Array(message.params.dropFirst())))
                case "NAK":
                    delegate?.onEvent(IRC.Event.capabilitiesRejected(capabilities: Array(message.params.dropFirst())))
                case "REQ":
                    delegate?.onEvent(IRC.Event.capabilitiesRequested(capabilities: Array(message.params.dropFirst())))
                case "LS":
                    delegate?.onEvent(IRC.Event.capabilitiesList(capabilities: Array(message.params.dropFirst())))
                case "LIST":
                    delegate?.onEvent(IRC.Event.capabilitiesActive(capabilities: Array(message.params.dropFirst())))
                default:
                    delegate?.onEvent(IRC.Event.unknown(message: message))
                }
            }
        case "PRIVMSG":
            if let prefix = message.prefix,
                message.params.count > 1,
                let recipient = message.params.first,
                let text = message.params.last {
                delegate?.onEvent(IRC.Event.privateMessage(user: prefix, recipient: recipient, message: text))
            }
        case "NOTICE":
            if let prefix = message.prefix,
                message.params.count > 1,
                let recipient = message.params.first,
                let text = message.params.last {
                delegate?.onEvent(IRC.Event.notice(user: prefix, recipient: recipient, message: text))
            }
            break
        case let code where code.count == 3 && (code.starts(with: "4") || code.starts(with: "5")):
            // Common error codes handling.
            if let prefix = message.prefix {
                let text = message.params.dropFirst().joined(separator: " ")
                delegate?.onEvent(IRC.Event.errorReply(from: prefix, code: code, message: text))
            }
        default:
            delegate?.onEvent(IRC.Event.unknown(message: message))
        }
    }
}

/// Bridge to client convenience methods.
extension IRC.Controller {
    
    /// Nickname message.
    ///
    /// - parameter name: User's nickname to register
    public func nick(_ name: String) {
        client.nick(name)
    }
    
    /// Quit message.
    ///
    /// - parameter message: Farawell message
    public func quit(_ message: String? = nil) {
        client.quit(message)
    }
    
    /// User registration message.
    ///
    /// - parameter name: User's nickname to register
    /// - parameter mode: User mode
    /// - parameter realname: User's real name
    public func user(_ name: String, mode: UInt32 = 0, realname: String? = nil) {
        client.user(name, mode: mode, realname: realname)
    }
    
    /// Join channel message.
    ///
    /// - parameter chat: Name of the chat
    public func join(_ chat: String) {
        client.join(chat)
    }
    
    /// Part channel message.
    ///
    /// - parameter chat: Name of the chat
    public func part(_ chat: String) {
        client.part(chat)
    }
    
    /// Private message.
    ///
    /// - parameter who: Recipients
    /// - parameter message: Message content
    public func privateMessage(who: String, message: String) {
        client.privateMessage(who: who, message: message)
    }
    
    /// Pass message.
    /// - parameter pass: Password
    ///
    public func pass(_ pass: String) {
        client.pass(pass)
    }
    
    /// Names message.
    ///
    /// - parameter channel: Channel name
    public func names(_ channel: String) {
        client.names(channel)
    }
    
    /// Require capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func requireCapabilities(capabilities: [String]) {
        client.requireCapabilities(capabilities: capabilities)
    }
    
    /// End capabilities negotiations message.
    public func endCapabilitiesNegotiations() {
        client.endCapabilitiesNegotiations()
    }
    
    /// Acknowledge capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func acknowledgeCapabilities(capabilities: [String]) {
        client.acknowledgeCapabilities(capabilities: capabilities)
    }
    
    /// Reject capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func rejectCapabilities(capabilities: [String]) {
        client.rejectCapabilities(capabilities: capabilities)
    }
    
    /// List all capabilities supported by server.
    public func listAllCapabilities() {
        client.listAllCapabilities()
    }
    
    /// List active capabilities.
    public func listActiveCapabilities() {
        client.listActiveCapabilities()
    }
}
