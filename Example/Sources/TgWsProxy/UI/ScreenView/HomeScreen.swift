import SwiftUI

struct HomeScreen: View {
    
    @EnvironmentObject var proxy: ProxyManager
    
    @State private var showLink = false

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader
                .padding(.bottom, 16)

            // Stats card
            if proxy.isRunning {
                statsCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Connect info
            if proxy.isRunning {
                connectCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Spacer()

            // Start/Stop button
            startStopButton
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("TG WS Proxy")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: proxy.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(proxy.isRunning ? .green : .secondary)

            Text(proxy.isRunning
                 ? R.string.localizable.homeScreenProxyActiveStatus()
                 : R.string.localizable.homeScreenProxyInactiveStatus())
                .font(.headline)
                .foregroundColor(proxy.isRunning ? .primary : .secondary)

            if proxy.isRunning {
                Text("\(proxy.config.host):\(proxy.config.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 16)
    }

    private var statsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(R.string.localizable.homeScreenTrafficStat)
                    .font(.subheadline.bold())
                Spacer()
            }
            HStack(spacing: 16) {
                statItem(R.string.localizable.homeScreenTrafficConnections(), value: "\(proxy.stats.connectionsActive)")
                statItem("WS", value: "\(proxy.stats.connectionsWS)")
                statItem("↑", value: formatBytes(proxy.stats.bytesUp))
                statItem("↓", value: formatBytes(proxy.stats.bytesDown))
            }
        }
        .padding()
        //.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(R.string.localizable.homeScreenTrafficConnectionInfoCard())
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    UIPasteboard.general.string = proxy.config.tgConnectDeeplinkString
                } label: {
                    Label(R.string.localizable.generalCopy(), systemImage: "doc.on.doc")
                        .font(.caption)
                }
            }

            Text(R.string.localizable.homeScreenProxySettingsInfo)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                infoRow(R.string.localizable.generalSrv(), value: proxy.config.host)
                infoRow(R.string.localizable.generalSrvPort(), value: "\(proxy.config.port)")
                infoRow(R.string.localizable.generalMTProtoSecret(), value: "dd\(proxy.config.secret)")
            }
            .font(.system(.caption, design: .monospaced))

            Button {
                if let url = URL(string: proxy.config.tgConnectDeeplinkString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(R.string.localizable.homeScreenProxySettingsOpenInTlg(), systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        //.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }

    private var startStopButton: some View {
        Button {
            if proxy.isRunning {
                proxy.stopProxy()
            } else {
                proxy.startProxy()
            }
        } label: {
            HStack {
                Image(systemName: proxy.isRunning ? "stop.fill" : "play.fill")
                Text(proxy.isRunning
                     ? R.string.localizable.homeScreenProxyStop
                     : R.string.localizable.homeScreenProxyStart)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        //.buttonStyle(.borderedProminent)
        //.tint(proxy.isRunning ? .red : .green)
        //.controlSize(.large)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        for unit in units {
            if value < 1024 { return String(format: "%.1f%@", value, unit) }
            value /= 1024
        }
        return String(format: "%.1f TB", value)
    }
}

#if DEBUG
#Preview {
    NavigationView {
        HomeScreen()
    }
    .environmentObject(previewProxyManager)
}
#endif
