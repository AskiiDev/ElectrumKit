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

### Method-routed subscriptions (protocol extensions)

Standard Electrum notifications echo the subscription's request parameters, so they can
be matched by `method + params`. Some protocol extensions - notably
[Frigate](https://github.com/sparrowwallet/frigate) silent payments - instead deliver
by-name **object** params (`{"subscription": …, "progress": …, "history": […]}`) that do
not echo the request. Route those by method name with `subscribe(toMethod:)`, whose
handler receives the raw notification params:

```swift
client.subscribe(
    toMethod: "blockchain.silentpayments.subscribe",
    params: [scanPrivKeyHex, spendPubKeyHex, startHeight]
) { params in
    guard let body = params as? [String: Any],
          let history = body["history"] as? [[String: Any]] else { return }
    // each entry: { "height": Int, "tx_hash": String, "tweak_key": String }
}
```

> Numeric JSON fields decode as `Int` when integral (e.g. `progress: 1.0` → `Int 1`) and
> `Double` otherwise; read them via `NSNumber` (`(value as? NSNumber)?.doubleValue`).

### Connection state

```swift
switch client.connectionState {
case .connected:   …
case .connecting:  …
case .disconnected, .stopped: …
}
```

## Testing

```sh
swift test
```

Unit tests cover the JSON-RPC codec (including positional vs. by-name notifications),
configuration, and error handling. Connection, TLS pinning, and live notification routing
are validated against a real Electrum / Frigate endpoint as integration tests.

## Contributing

Contributions are welcome. Please submit pull requests or open issues for bugs and feature requests.
