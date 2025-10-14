# ElectrumKit

**ElectrumKit** is a secure, lightweight and dependency-free Swift client for Electrum servers. 

## Features
- **No external dependencies:** Uses only Apple system frameworks (`Foundation`, `CryptoKit`, `Security`, `Network`)
- **TLS security:** Supports Trust-On-First-Use (TOFU) certificate pinning and system CA verification
- **Privacy:** Packet buffering and padding to help mitigate traffic analysis for < `TLS 1.3`
- **Reliability:** Automatic reconnection with exponential backoff and jitter

## Requirements
- iOS 15.0+ / macOS 12.0+
- Swift 5.7+

## Usage examples
### Basic Setup
```swift
import ElectrumKit

let client = ElectrumClient(
    host: "blockstream.info",
    port: 700
)

client.start()

// Do stuff...

client.stop()
```

### Making requests
```swift
client.request(
    method: "blockchain.scripthash.get_balance",
    params: [scripthash],
    timeout: 10.0
) { result in
    switch result {
    case .success(let balance):
        print("Balance: \(balance)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Making subscriptions
```swift
client.subscribe(
    method: "blockchain.headers.subscribe",
    params: []
) { notification in
    print("Received notification: \(notification)")
}
```

## Contributing

Contributions are welcome. Please submit pull requests or open issues for bugs and feature requests.
