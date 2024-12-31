import SwiftUI
import Combine

struct ContentView: View {
    @State private var response: String = ""
    @State private var tvIP: String = "192.168.0.24" // Default value, user can edit
    @State private var isConnected: Bool = false
    @State private var webSocketTask: URLSessionWebSocketTask?
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        VStack(spacing: 8) {
            // Title
            Text("Samsung TV Remote")
                .font(.title)
                .foregroundColor(.primary)
                .padding(.bottom, 16)
            
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
                
                // Connect/Disconnect Button
                Button(action: {
                    connectToTV()
                    generator.impactOccurred()
                }) {
                    Text(isConnected ? "Connected" : "Connect")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConnected ? Color.green : Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Remote Controls
            VStack(spacing: 24) {
                // Power & Mute
                HStack(spacing: 16) {
                    remoteButton(title: "Power", action: { sendCommand("KEY_POWER") }, icon: "power", color: .red)
                    remoteButton(title: "Mute", action: { sendCommand("KEY_MUTE") }, icon: "speaker.slash", color: .red)
                }
                
                // Volume Controls
                HStack(spacing: 16) {
                    remoteButton(title: "Vol +", action: { sendCommand("KEY_VOLUP") }, icon: "volume.up", color: .blue)
                    remoteButton(title: "Vol -", action: { sendCommand("KEY_VOLDOWN") }, icon: "volume.down", color: .blue)
                }
                
                // Channel Controls
                HStack(spacing: 16) {
                    remoteButton(title: "Ch +", action: { sendCommand("KEY_CHUP") }, icon: "arrow.up", color: .green)
                    remoteButton(title: "Ch -", action: { sendCommand("KEY_CHDOWN") }, icon: "arrow.down", color: .green)
                }
                
                // Navigation Controls
                VStack(spacing: 8) {
                    remoteButton(title: "▲", action: { sendCommand("KEY_UP") }, color: .orange)
                    HStack(spacing: 10) {
                        remoteButton(title: "◀", action: { sendCommand("KEY_LEFT") }, color: .orange)
                        remoteButton(title: "OK", action: { sendCommand("KEY_ENTER") }, color: .orange)
                        remoteButton(title: "▶", action: { sendCommand("KEY_RIGHT") }, color: .orange)
                    }
                    remoteButton(title: "▼", action: { sendCommand("KEY_DOWN") }, color: .orange)
                }
                
                // Home & Back
                HStack(spacing: 16) {
                    remoteButton(title: "Home", action: { sendCommand("KEY_HOME") }, icon: "house", color: .orange)
                    remoteButton(title: "Back", action: { sendCommand("KEY_RETURN") }, icon: "arrow.uturn.left", color: .orange)
                }
                
                // Additional Buttons
                HStack(spacing: 16) {
                    remoteButton(title: "Settings", action: { sendCommand("KEY_MENU") }, icon: "gearshape", color: .purple)
                    remoteButton(title: "Source", action: { sendCommand("KEY_SOURCE") }, icon: "rectangle.on.rectangle", color: .purple)
                }
                HStack(spacing: 16) {
                    remoteButton(title: "Netflix", action: { sendCommand("KEY_NETFLIX") }, icon: "play.rectangle.fill", color: .purple)
                    remoteButton(title: "Guide", action: { sendCommand("KEY_GUIDE") }, icon: "list.bullet", color: .purple)
                    remoteButton(title: "Exit", action: { sendCommand("KEY_EXIT") }, icon: "xmark.circle", color: .purple)
                }
            }
            .padding()
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear {
            disconnectFromTV()
        }
    }
    
    func remoteButton(title: String, action: @escaping () -> Void, icon: String? = nil, color: Color) -> some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .bold()
            .frame(width: 100, height: 50)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(6)
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
