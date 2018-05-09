IRCClient
===========
A simple Swift framework to communicate to IRC servers.

This is a small side project I wanted to implement to use in other stuff. The design is far from final, there are probably some bugs, and there's a change I could rewrite big chunks of it depending on requirements of that "other stuff", or abandon it altogether. That said, it is useful for me as a starting point, so maybe it will be useful for someone else. Any contributions are welcome as well.

Usage
-----
There are two entry points: `IRC.Client` and `IRC.Controller`. Client does most of the work with connecting to server and receiving and sending IRC messages. `IRC.Controller` is a little helper that catches `Client`'s delegate calls and transforms them into a more useful `IRC.Event` objects.

```swift
let client = IRC.Client()
let controller = IRC.Controller(client: client)
controller.delegate = self

let host = "irc.rizon.net"
let port = 6667
let nick = "some_guy"

controller.connect(host: host, port: port!)
controller.pass(pass)
controller.nick(nick)
controller.user(nick, realname: "Alexander Rogachev")

```

To catch messages coming from the server, you should implement `IRCControllerDelegate` protocol, which contains of only one method - `onEvent`. Here's a simple example:

```swift
func onEvent(_ event: IRC.Event) {
    switch event {
    case .channelJoin(let user, let channel):
        print("*** <\(user)> joined \(channel) ***")
    case .channelPart(let user, let channel):
         print("*** <\(user)> parted \(channel) ***")
    case .privateMessage(let user, let recipient, let message):
        if (recipient.starts(with: "#")) {
            terminal.write(line: "\(recipient) <\(username)> \(message)")
        } else {
            terminal.write(line: "<\(username)> to <\(recipient)>: \(message)")
        }
    default:
        print("*** Unknown IRC message received ***")
    }
}
```

Status
------
- No unit tests
- No support for XDCC or any other file transfer extension
- Haven't even tested with SSL connections