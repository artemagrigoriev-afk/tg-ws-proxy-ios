import SwiftUI
import SwTgWs

struct SettingsScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var proxy: ProxyManager

    @State private var host: String = ""
    @State private var port: String = ""
    @State private var secret: String = ""
    @State private var dcLines: String = ""
    @State private var bufferKB: String = ""
    @State private var poolSize: String = ""
    @State private var verbose: Bool = false
    @State private var showError: String? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: .zero) {
                    Text(R.string.localizable.settingsMTProtoConnCard)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(R.string.localizable.settingsMTProtoConnIP)
                    TextField("127.0.0.1", text: $host)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 4, leading: .zero, bottom: 10, trailing: .zero))
                        .textFieldStyle(.roundedBorder)
                    
                    Text(R.string.localizable.generalSrvPort)
                    TextField("1443", text: $port)
                        .multilineTextAlignment(.leading)
                        .keyboardType(.numberPad)
                        .padding(EdgeInsets(top: 4, leading: .zero, bottom: 10, trailing: .zero))
                        .textFieldStyle(.roundedBorder)
                    
                    Text(R.string.localizable.generalMTProtoSecret)
                    HStack {
                        TextField("hex secret", text: $secret)
                            .multilineTextAlignment(.leading)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                        Button {
                            secret = STWMTProtoProxyConfig.generateRandomSecretHexString()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .padding(EdgeInsets(top: 4, leading: .zero, bottom: .zero, trailing: .zero))
                }
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary)
                .cornerRadius(12.0)
                
                VStack(alignment: .leading, spacing: .zero) {
                    Text(R.string.localizable.settingsDCListCard)
                        .font(.title3)
                        .fontWeight(.semibold)
                    TextEditor(text: $dcLines)
                        .frame(minHeight: 80)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary)
                .cornerRadius(12.0)
                
                VStack(alignment: .leading, spacing: .zero) {
                    Text(R.string.localizable.settingsProxyPower)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(R.string.localizable.settingsProxyPowerBuffSize)
                    TextField("256", text: $bufferKB)
                        .multilineTextAlignment(.leading)
                        .keyboardType(.numberPad)
                        .padding(EdgeInsets(top: 4, leading: .zero, bottom: 10, trailing: .zero))
                        .textFieldStyle(.roundedBorder)
                    
                    Text(R.string.localizable.settingsProxyPowerWsSessions)
                    TextField("4", text: $poolSize)
                        .multilineTextAlignment(.leading)
                        .keyboardType(.numberPad)
                        .padding(EdgeInsets(top: 4, leading: .zero, bottom: 10, trailing: .zero))
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle(R.string.localizable.settingsProxyPowerDetailedLogs(), isOn: $verbose)

                    if let error = showError {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary)
                .cornerRadius(12.0)

                HStack {
                    Text(R.string.localizable.generalVersion)
                    Spacer()
                    Text("1.4.0-ios")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .navigationTitle(R.string.localizable.generalSettings())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Text(R.string.localizable.generalSave)
                        .fontWeight(.semibold)
                }
            }
        })
        .onAppear { loadConfig() }
    }

    private func loadConfig() {
        let cfg = proxy.config
        host = cfg.host
        port = String(cfg.port)
        secret = cfg.secret
        dcLines = cfg.dcRedirects.map { "\($0.key):\($0.value)" }.joined(separator: "\n")
        bufferKB = String(cfg.bufSizeKb)
        poolSize = "\(cfg.poolSize)"
    }

    private func save() {
        guard let portInt = UInt16(port), portInt > 0 else {
            showError = R.string.localizable.settingsInvalidPortErrMsg()
            return
        }
        guard secret.count == 32, UInt64(secret.prefix(16), radix: 16) != nil else {
            showError = R.string.localizable.settingsInvalidSecretErrMsg()
            return
        }
        let secretBytes = STWBinaryUtil.hexToBytes(secret)
        var bufSize = UInt32(bufferKB)
        if let safeBufSize = bufSize {
            bufSize = safeBufSize * 1024
        }

        var dcRedirects: [Int: String] = [:]
        for line in dcLines.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let dc = Int(parts[0]) else {
                showError = R.string.localizable.settingsInvalidDcErrMsg() + " " + trimmed
                return
            }
            dcRedirects[dc] = String(parts[1])
        }

        proxy.config = proxy.config.copyWith(host: host, port: portInt, secret: secretBytes, dcRedirects: dcRedirects, bufSize: bufSize, poolSize: Int(poolSize))
        proxy.saveConfig()
        presentationMode.wrappedValue.dismiss()
    }
}

#if DEBUG
#Preview {
    NavigationView {
        SettingsScreen()
    }
    .environmentObject(previewProxyManager)
}
#endif
