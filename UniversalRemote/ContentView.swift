import SwiftUI
import Combine

struct ContentView: View {
    @State private var response: String = ""
    @State private var tvIP: String = "192.168.0.24" // Default value, user can edit
    @State private var isConnected: Bool = false
    @State private var webSocketTask: URLSessionWebSocketTask?
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Samsung TV Remote")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding()
            
            // IP Text Field
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.purple)
                TextField("Enter TV IP", text: $tvIP)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.purple, lineWidth: 1)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.secondarySystemBackground)))
                    )
            }
            .padding([.horizontal])
            
            // Connection Status
            Text(isConnected ? "Connected to TV" : "Not Connected")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isConnected ? .green : .red)
                .padding(.top, 10)
            
            // Connect/Disconnect Button
            Button(action: {
                connectToTV()
                generator.impactOccurred()
            }) {
                Text(isConnected ? "Reconnect to TV" : "Connect to TV")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isConnected ? Color.green : Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding([.horizontal])
            
            // Remote Controls
            VStack(spacing: 15) {
                // Power & Mute
                HStack(spacing: 20) {
                    remoteButton(title: "Power", action: { sendCommand("KEY_POWER") }, icon: "power")
                    remoteButton(title: "Mute", action: { sendCommand("KEY_MUTE") }, icon: "speaker.slash")
                }
                
                // Volume Controls
                HStack(spacing: 20) {
                    remoteButton(title: "Vol +", action: { sendCommand("KEY_VOLUP") }, icon: "volume.up")
                    remoteButton(title: "Vol -", action: { sendCommand("KEY_VOLDOWN") }, icon: "volume.down")
                }
                
                // Channel Controls
                HStack(spacing: 20) {
                    remoteButton(title: "Ch +", action: { sendCommand("KEY_CHUP") }, icon: "arrow.up")
                    remoteButton(title: "Ch -", action: { sendCommand("KEY_CHDOWN") }, icon: "arrow.down")
                }
                
                // Navigation Controls
                VStack(spacing: 10) {
                    remoteButton(title: "▲", action: { sendCommand("KEY_UP") })
                    HStack(spacing: 20) {
                        remoteButton(title: "◀", action: { sendCommand("KEY_LEFT") })
                        remoteButton(title: "OK", action: { sendCommand("KEY_ENTER") })
                        remoteButton(title: "▶", action: { sendCommand("KEY_RIGHT") })
                    }
                    remoteButton(title: "▼", action: { sendCommand("KEY_DOWN") })
                }
                
                // Home & Back
                HStack(spacing: 20) {
                    remoteButton(title: "Home", action: { sendCommand("KEY_HOME") }, icon: "house")
                    remoteButton(title: "Back", action: { sendCommand("KEY_RETURN") }, icon: "arrow.uturn.left")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal)
            
            // Response Display
            Text("Response: \(response)")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding()
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear {
            disconnectFromTV()
        }
    }
    
    func remoteButton(title: String, action: @escaping () -> Void, icon: String? = nil) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(width: 100, height: 50)
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    func connectToTV() {
        guard let url = URL(string: "ws://\(tvIP):8001/api/v2/channels/samsung.remote.control") else {
            response = "Invalid WebSocket URL."
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        response = "Connected to TV WebSocket."
        
        receiveMessages() // Start listening for responses
    }
    
    func disconnectFromTV() {
        generator.impactOccurred()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        response = "Disconnected from TV."
    }
    
    func sendCommand(_ command: String) {
        guard let webSocketTask = webSocketTask else {
            response = "WebSocket is not connected."
            return
        }
        
        generator.impactOccurred()
        
        let message = """
        {
            "method": "ms.remote.control",
            "params": {
                "Cmd": "Click",
                "DataOfCmd": "\(command)",
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            }
        }
        """
        
        webSocketTask.send(.string(message)) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.response = "Error sending command: \(error.localizedDescription)"
                }
            } else {
                DispatchQueue.main.async {
                    self.response = "Command sent: \(command)"
                }
            }
        }
    }
    
    func receiveMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.response = "Error receiving message: \(error.localizedDescription)"
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self.response = "Received: \(text)"
                    }
                case .data(let data):
                    DispatchQueue.main.async {
                        self.response = "Received binary data (\(data.count) bytes)"
                    }
                @unknown default:
                    DispatchQueue.main.async {
                        self.response = "Unknown message received."
                    }
                }
            }
            
            // Continue listening
            self.receiveMessages()
        }
    }
}

#Preview {
    ContentView()
}
