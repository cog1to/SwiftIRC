//
//  Client.swift
//  IRCClient
//
//  Created by Alexander Rogachev on 5/3/18.
//  Copyright © 2018 Alexander Rogachev. All rights reserved.
//

import Foundation

/// Client delegate protocol
public protocol IRCClientDelegate {
    
    /// Called when client recieves new message.
    ///
    /// - parameter client: Client instance that recieved the message.
    /// - parameter message: Message object containing recieved IRC message
    func onMessage(client: IRC.Client, message: IRC.Message)
    
    /// Called when client successfully opens connection to server.
    ///
    /// - parameter client: Client instance that generated the event
    func onConnected(client: IRC.Client)
    
    /// Called when client disconnects from server.
    ///
    /// - parameter client: Client instance that generated the event
    func onDisconnected(client: IRC.Client)
    
    /// Called when a network error occurs.
    ///
    /// - parameter client: Client instance that got an error
    /// - parameter error: Underlying error object, if one exists
    func onError(client: IRC.Client, error: Error?)
}

public extension IRC {
    
    /// IRC Client. Can connect to a server and recieve and send IRC-formatted messages.
    /// You can use it directly or coupled with IRC.Controller that adds an interpretation
    /// layer for raw IRC messages and some additional features to ease the control.
    public class Client: NSObject {
        
        /// Max buffer length.
        let maxReadLength: Int = 1024 * 1024
        
        /// Host name.
        var host: String!
        
        /// Port.
        var port: UInt32!
        
        /// Automatic reconnect flag.
        public var autoReconnect: Bool = false
        
        /// Delegate.
        public var delegate: IRCClientDelegate?
        
        /// Input stream that will recieve data from server.
        private var inputStream: InputStream!
        
        /// Output stream to send commands through.
        private var outputStream: OutputStream!
        
        /// Internal queue to attach streams.
        private var queue = DispatchQueue.init(label: "ru.aint.IRC.ClientQueue")
        
        /// Operation queue to handle stream events.
        private var operationQueue = OperationQueue()
        
        /// Creates new instance of IRC client.
        override public init() {
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.qualityOfService = .utility
            
            super.init()
        }
        
        /// Tries to make a connection to an IRC server.
        ///
        /// - parameter host: Host name.
        /// - parameter port: Port number.
        public func connect(host: String, port: UInt32) {
            self.host = host
            self.port = port
            
            // Creating streams.
            var readStream: Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?
            
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                               host as CFString,
                                               port,
                                               &readStream,
                                               &writeStream)
            
            self.inputStream = readStream!.takeRetainedValue()
            self.outputStream = writeStream!.takeRetainedValue()
            
            // Subscribing to input stream events.
            self.inputStream.delegate = self
            self.outputStream.delegate = self
            
            // Putting streams into a separate queue to prevent blocking main thread.
            CFReadStreamSetDispatchQueue(self.inputStream, self.queue)
            CFWriteStreamSetDispatchQueue(self.outputStream, self.queue)
            
            self.inputStream.schedule(in: .current, forMode: .commonModes)
            self.outputStream.schedule(in: .current, forMode: .commonModes)
            
            // Opening streams to start data transfer.
            self.inputStream.open()
            self.outputStream.open()
        }
        
        /// Closes existing connection.
        public func close() {
            inputStream.close()
            outputStream.close()
        }
        
        /// Sends a message.
        ///
        /// - parameter message: Message to send.
        public func send(message: IRC.Message) {
            let data = "\(message.raw)\r\n".data(using: .utf8)!
            _ = data.withUnsafeBytes { [weak self] in
                self?.outputStream.write($0, maxLength: data.count)
            }
        }
        
        deinit {
            close()
        }
    }
}

/// Stream events handling
extension IRC.Client: StreamDelegate {
    
    /// Handles stream events.
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            operationQueue.addOperation { [weak self] in
                self?.readAvailableBytes(stream: aStream as! InputStream)
            }
        case Stream.Event.endEncountered:
            // Notify the delegate.
            delegate?.onDisconnected(client: self)
            
            // Close existing streams.
            close()
            
            // If auto-reconnect is set up, try to connect again.
            if (autoReconnect) {
                connect(host: host, port: port)
            }
            break
        case Stream.Event.errorOccurred:
            delegate?.onError(client: self, error: aStream.streamError)
            break
        case Stream.Event.hasSpaceAvailable:
            break
        case Stream.Event.openCompleted:
            if (aStream == inputStream) {
                delegate?.onConnected(client: self)
            }
            break
        default:
            break
        }
    }
    
    /// Reads available data from a given stream.
    ///
    /// - parameter stream: Stream that contains data
    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            
            processData(buffer: buffer, length: numberOfBytesRead)
        }
        buffer.deallocate()
    }
    
    /// Processes raw input data.
    ///
    /// - parameter buffer: Byte array containing data to process
    /// - parameter length: Length of the data to process
    private func processData(buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        guard let string = String(bytesNoCopy: buffer,
                                  length: length,
                                  encoding: .utf8,
                                  freeWhenDone: false) else {
                                    return
        }
        
        guard string.contains("\r\n") else {
            return
        }
        
        let stringArray = string.components(separatedBy: "\r\n")
        let messages = stringArray.filter {
            $0.count > 0
        }.map {
            return IRC.Message(raw: $0)
        }.filter {
            $0 != nil
        }.map {
            $0!
        }
        
        for message in messages {
            delegate?.onMessage(client: self, message: message)
        }
    }
}

/// Convenient methods to send common messages to server.
public extension IRC.Client {
    
    /// Nickname message.
    ///
    /// - parameter name: User's nickname to register
    public func nick(_ name: String) {
        self.send(message: IRC.Message.nick(name: name))
    }
    
    /// Quit message.
    ///
    /// - parameter message: Farawell message
    public func quit(_ message: String? = nil) {
        self.send(message: IRC.Message.quit(message: message))
    }
    
    /// User registration message.
    ///
    /// - parameter name: User's nickname to register
    /// - parameter mode: User mode
    /// - parameter realname: User's real name
    public func user(_ name: String, mode: UInt32 = 0, realname: String? = nil) {
        self.send(message: IRC.Message.user(name: name, mode: mode, realname: realname))
    }
    
    /// Join channel message.
    ///
    /// - parameter chat: Name of the chat
    public func join(_ chat: String) {
        self.send(message: IRC.Message.join(channel: chat))
    }
    
    /// Part channel message.
    ///
    /// - parameter chat: Name of the chat
    public func part(_ chat: String) {
        self.send(message: IRC.Message.part(channel: chat))
    }
    
    /// Private message.
    ///
    /// - parameter who: Recipients
    /// - parameter message: Message content
    public func privateMessage(who: String, message: String) {
        self.send(message: IRC.Message.privateMessage(who: who, message: message))
    }
    
    /// Pass message.
    /// - parameter pass: Password
    ///
    public func pass(_ pass: String) {
        self.send(message: IRC.Message.pass(pass))
    }
    
    /// Names message.
    ///
    /// - parameter channel: Channel name
    public func names(_ channel: String) {
        self.send(message: IRC.Message.names(channel))
    }
    
    /// Require capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func requireCapabilities(capabilities: [String]) {
        self.send(message: IRC.Message.requireCapabilities(capabilities: capabilities))
    }
    
    /// End capabilities negotiations message.
    public func endCapabilitiesNegotiations() {
        self.send(message: IRC.Message.endCapabilitiesNegotiation())
    }
    
    /// Acknowledge capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func acknowledgeCapabilities(capabilities: [String]) {
        self.send(message: IRC.Message.acknowledgeCapabilities(capabilities: capabilities))
    }
    
    /// Reject capability message.
    ///
    /// - parameter capabilities: Capabilities list
    public func rejectCapabilities(capabilities: [String]) {
        self.send(message: IRC.Message.rejectCapabilities(capabilities: capabilities))
    }
    
    /// List all capabilities supported by server.
    public func listAllCapabilities() {
        self.send(message: IRC.Message.listAllCapabilities())
    }
    
    /// List active capabilities.
    public func listActiveCapabilities() {
        self.send(message: IRC.Message.listActiveCapabilities())
    }
}
