//
//  Message.swift
//  IRCClient
//
//  Created by Alexander Rogachev on 5/3/18.
//  Copyright © 2018 Alexander Rogachev. All rights reserved.
//

import Foundation

public extension IRC {
    
    /// IRC Message class.
    public class Message {
        
        /// List of tags.
        let tags: [String]?
        
        /// Message prefix.
        let prefix: String?
        
        /// Command name.
        let name: String
        
        /// Message parameters.
        let params: [String]
        
        init(name: String, params: [String]? = nil) {
            self.name = name
            self.params = params ?? []
            self.tags = []
            self.prefix = nil
        }
        
        init(prefix: String, name: String, params: [String]? = nil) {
            self.prefix = prefix
            self.name = name
            self.params = params ?? []
            self.tags = []
        }
        
        init(tags: [String], prefix: String, name: String, params: [String]? = nil) {
            self.tags = tags
            self.prefix = prefix
            self.name = name
            self.params = params ?? []
        }
        
        /// Initializes new Message instance from raw input string.
        ///
        /// - parameter raw: Raw message/command string.
        public init?(raw: String) {
            var regex: NSRegularExpression!
            do {
                regex = try NSRegularExpression(pattern: "^(?:@([^\r\n ]*) +|())(?::([^\r\n ]+) +|())([^\r\n ]+)(?: +([^:\r\n ]+[^\r\n ]*(?: +[^:\r\n ]+[^\r\n ]*)*)|())?(?: +:([^\r\n]*)| +())?$", options: [])
            } catch {
                return nil
            }
            
            var tags: [String]?
            var prefix: String?
            var name: String?
            var params: [String]?
            
            if let match = regex.firstMatch(in: raw, options: [], range: NSRange(location: 0, length: raw.utf16.count)) {
                for rangeIndex in 1..<match.numberOfRanges {
                    let range = match.range(at: rangeIndex)
                    
                    guard range.location != NSNotFound else {
                        continue
                    }
                    
                    let startIndex = raw.utf16.index(raw.startIndex, offsetBy: range.location)
                    let endIndex = raw.utf16.index(startIndex, offsetBy: range.length)
                    let group = String(raw.utf16[startIndex..<endIndex])!
                    
                    switch rangeIndex {
                    case 1:
                        // Tags
                        tags = group.components(separatedBy: ";")
                    case 3:
                        // Prefix
                        prefix = group
                    case 5:
                        // Name
                        name = group
                    case 6:
                        // Params
                        params = group.components(separatedBy: " ")
                    case 8:
                        // Last parameter
                        if (params == nil) {
                            params = []
                        }
                        params!.append(group)
                    default:
                        // Unknown group?
                        break;
                    }
                }
            }
            
            if let name = name, let params = params {
                self.name = name
                self.prefix = prefix
                self.tags = tags
                self.params = params
            } else {
                return nil
            }
        }
        
        /// Text representation of the message.
        public var raw: String {
            var message: String = ""
            
            if let tags = tags, tags.count > 0 {
                message.append("@" + tags.joined(separator: ";") + " ")
            }
            
            if let prefix = prefix, prefix.count > 0 {
                message.append(":\(prefix) ")
            }
            
            if name.count > 0 {
                message.append("\(name)")
            }
            
            if params.count > 0 {
                for (index, param) in params.enumerated() {
                    if index == params.count - 1 {
                        message.append(" :\(param)")
                    } else {
                        message.append(" \(param)")
                    }
                }
            }
            
            return message
        }
    }
}

/// Convenient functions for creating common commands and messages.
public extension IRC.Message {
    
    /// Creates a NICK command.
    ///
    /// - parameter name: Username to register with NICK command
    /// - returns: Message object containing NICK command for specified username
    public class func nick(name: String) -> IRC.Message {
        return IRC.Message(name: "NICK", params: [name])
    }
    
    /// Creates a NOTICE command.
    ///
    /// - parameter who: Message recipients
    /// - parameter message: Message content
    /// - returns: Message object containing NOTICE command for given recipients with specified text
    public class func notice(who: String, message: String) -> IRC.Message {
        return IRC.Message(name: "NOTICE", params: [who, message])
    }
    
    /// Creates a USER command.
    ///
    /// - parameter name: Username to register with USER command
    /// - parameter mode: Mode value.
    /// - parameter realname: User's real name
    /// - returns: Message object containing USER command
    public class func user(name: String, mode: UInt32, realname: String? = nil) -> IRC.Message {
        var params = [name, "\(mode)", "*"]
        if let realname = realname {
            params.append(realname)
        } else {
            params.append(name)
        }
        
        return IRC.Message(name: "USER", params: params)
    }
    
    /// Creates a PING command.
    ///
    /// - parameter value: Value to pass with PING command
    /// - returns: Message object containing PING command with specified value
    public class func ping(value: String?) -> IRC.Message {
        return IRC.Message(name: "PING", params: value != nil ? [value!] : [])
    }
    
    /// Creates a PONG command.
    ///
    /// - parameter value: Value to pass with PONG command
    /// - returns: Message object containing PONG command with specified value
    public class func pong(value: String?) -> IRC.Message {
        return IRC.Message(name: "PONG", params: value != nil ? [value!] : [])
    }
    
    /// Creates a QUIT command.
    ///
    /// - parameter message: Farawell message
    /// - returns: Message object containing QUIT command with specified message
    public class func quit(message: String? = nil) -> IRC.Message {
        return IRC.Message(name: "QUIT", params: message != nil ? [message!] : [])
    }
    
    /// Creates a JOIN command.
    ///
    /// - parameter channel: Channel name to join
    /// - returns: Message object containing JOIN command with specified channel name
    public class func join(channel: String) -> IRC.Message {
        return IRC.Message(name: "JOIN", params: [channel])
    }
    
    /// Creates a PART command.
    ///
    /// - parameter channel: Channel name to part from
    /// - returns: Message object containing PART command with specified channel name
    public class func part(channel: String) -> IRC.Message {
        return IRC.Message(name: "PART", params: [channel])
    }
    
    /// Creates a PRIVMSG command.
    ///
    /// - parameter who: Channel name to join
    /// - parameter message: Message text
    /// - returns: Message object containing PRIVMSG command with specified recipient and text
    public class func privateMessage(who: String, message: String) -> IRC.Message {
        return IRC.Message(name: "PRIVMSG", params: [who, message])
    }
    
    /// Creates a PASS command.
    ///
    /// - parameter pass: Password string
    /// - returns: Message object containing PASS command with specified password string
    public class func pass(_ pass: String) -> IRC.Message {
        return IRC.Message(name: "PASS", params: [pass])
    }
    
    /// Creates a NAMES command.
    ///
    /// - parameter channel: Channel name to list names from
    /// - returns: Message object containing NAMES command with specified channel name
    public class func names(_ channel: String) -> IRC.Message {
        return IRC.Message(name: "NAMES", params: [channel])
    }
    
    /// Creates a CAP LS command.
    ///
    /// - returns: Message object containing CAP LS command
    public class func listAllCapabilities() -> IRC.Message {
        return IRC.Message(name: "CAP LS", params: [])
    }
    
    /// Creates a CAP LIST command.
    ///
    /// - returns: Message object containing CAP LIST command
    public class func listActiveCapabilities() -> IRC.Message {
        return IRC.Message(name: "CAP LIST", params: [])
    }
    
    /// Creates a CAP REQ command.
    ///
    /// - parameter capabilities: List of capabilities to require from server
    /// - returns: Message object containing CAP REQ command
    public class func requireCapabilities(capabilities: [String]) -> IRC.Message {
        return IRC.Message(name: "CAP REQ", params: [capabilities.joined(separator: " ")])
    }
    
    /// Creates a CAP END command.
    ///
    /// - returns: Message object containing CAP END command
    public class func endCapabilitiesNegotiation() -> IRC.Message {
        return IRC.Message(name: "CAP END")
    }
    
    /// Creates a CAP ACK command.
    ///
    /// - parameter capabilities: List of capabilities to acknowledge
    /// - returns: Message object containing CAP ACK command with given capabilities
    public class func acknowledgeCapabilities(capabilities: [String]) -> IRC.Message {
        return IRC.Message(name: "CAP ACK", params: [capabilities.joined(separator: " ")])
    }
    
    /// Creates a CAP NAK command.
    ///
    /// - parameter capabilities: List of capabilities to reject from server
    /// - returns: Message object containing CAP NAK command with given capabilities
    public class func rejectCapabilities(capabilities: [String]) -> IRC.Message {
        return IRC.Message(name: "CAP NAK", params: [capabilities.joined(separator: " ")])
    }
    
    /// Creates a VERSION command.
    ///
    /// - parameter to: Command recipient
    /// - parameter value: Version string
    /// - returns: Message object containing VERSION command with specified recipient and version value
    public class func version(to: String?, value: String) -> IRC.Message {
        return IRC.Message(name: "VERSION", params: to != nil ? [to!, value] : [value])
    }
}
