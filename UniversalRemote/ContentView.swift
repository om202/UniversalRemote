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
            Text("Samsung TV Remote")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter TV IP", text: $tvIP)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .keyboardType(.decimalPad)
            
            if isConnected {
                Text("Connected to TV")
                    .foregroundColor(.green)
            } else {
                Text("Not Connected")
                    .foregroundColor(.red)
            }
            
            Button(action: {
                connectToTV()
                generator.impactOccurred()
            }) {
                Text(isConnected ? "Reconnect to TV" : "Connect to TV")
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // Remote Controls
            VStack(spacing: 10) {
                HStack {
                    Button(action: { sendCommand("KEY_POWER") }) {
                        Text("Power")
                    }
                    .buttonStyle(RemoteButtonStyle())
                    
                    Button(action: { sendCommand("KEY_MUTE") }) {
                        Text("Mute")
                    }
                    .buttonStyle(RemoteButtonStyle())
                }
                
                HStack {
                    Button(action: { sendCommand("KEY_VOLUP") }) {
                        Text("Vol +")
                    }
                    .buttonStyle(RemoteButtonStyle())
                    
                    Button(action: { sendCommand("KEY_VOLDOWN") }) {
                        Text("Vol -")
                    }
                    .buttonStyle(RemoteButtonStyle())
                }
                
                HStack {
                    Button(action: { sendCommand("KEY_CHUP") }) {
                        Text("Ch +")
                    }
                    .buttonStyle(RemoteButtonStyle())
                    
                    Button(action: { sendCommand("KEY_CHDOWN") }) {
                        Text("Ch -")
                    }
                    .buttonStyle(RemoteButtonStyle())
                }
                
                // Navigation Controls
                VStack(spacing: 10) {
                    Button(action: { sendCommand("KEY_UP") }) {
                        Text("▲")
                    }
                    .buttonStyle(RemoteButtonStyle())
                    
                    HStack {
                        Button(action: { sendCommand("KEY_LEFT") }) {
                            Text("◀")
                        }
                        .buttonStyle(RemoteButtonStyle())
                        
                        Button(action: { sendCommand("KEY_ENTER") }) {
                            Text("OK")
                        }
                        .buttonStyle(RemoteButtonStyle())
                        
                        Button(action: { sendCommand("KEY_RIGHT") }) {
                            Text("▶")
                        }
                        .buttonStyle(RemoteButtonStyle())
                    }
                    
                    Button(action: { sendCommand("KEY_DOWN") }) {
                        Text("▼")
                    }
                    .buttonStyle(RemoteButtonStyle())
                }
                
                HStack {
                    Button(action: { sendCommand("KEY_HOME") }) {
                        Text("Home")
                    }
                    .buttonStyle(RemoteButtonStyle())
                    
                    Button(action: { sendCommand("KEY_RETURN") }) {
                        Text("Back")
                    }
                    .buttonStyle(RemoteButtonStyle())
                }
            }
            
            Text("Response: \(response)")
                .padding()
                .foregroundColor(.gray)
        }
        .padding()
        .onDisappear {
            disconnectFromTV()
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

struct RemoteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(width: 80, height: 50)
            .background(configuration.isPressed ? Color.gray : Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
