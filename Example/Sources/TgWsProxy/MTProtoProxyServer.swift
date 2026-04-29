import Foundation
import Network
import os.log
import SwTgWs

private let logger = Logger(subsystem: Constants.PSEUDO_BUNDLE_ID, category: "ProxyServer")

// MARK: - MTProto Proxy Server

final class MTProtoProxyServer {
    
    private let config: STWMTProtoProxyConfig
    private var listener: NWListener?
    private var statsCallback: ((ProxyStats) -> Void)?
    private let statsActor = StatsActor()

    init(config: STWMTProtoProxyConfig, statsCallback: ((ProxyStats) -> Void)? = nil) {
        self.config = config
        self.statsCallback = statsCallback
    }

    func start() async throws {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true

        let params = NWParameters(tls: nil, tcp: tcpOptions)

        let port = NWEndpoint.Port(rawValue: UInt16(config.port))!
        listener = try NWListener(using: params, on: port)

        listener?.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task {
                await self.handleNewConnection(connection)
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.listener?.stateUpdateHandler = nil
                    logger.info("Proxy server listening on port \(self?.config.port ?? 0)")
                    cont.resume()

                case .failed(let error):
                    self?.listener?.stateUpdateHandler = nil
                    logger.error("Listener failed: \(error)")
                    cont.resume(throwing: error)

                case .cancelled:
                    self?.listener?.stateUpdateHandler = nil
                    cont.resume(throwing: CancellationError())

                default:
                    break
                }
            }
            listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
        }

        // Start periodic stats reporting
        Task {
            while listener != nil {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let currentStats = await statsActor.getStats()
                statsCallback?(currentStats)
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleNewConnection(_ connection: NWConnection) async {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))

        await statsActor.update { $0.connectionsTotal += 1 }
        await statsActor.update { $0.connectionsActive += 1 }

        do {
            try await processClient(connection)
        } catch {
            logger.debug("Client connection error: \(error)")
        }
        
        await statsActor.update { $0.connectionsActive -= 1 }
        connection.cancel()
    }

    private func processClient(_ connection: NWConnection) async throws {
        // Wait for connection ready
        try await waitForReady(connection)

        // Read 64-byte handshake
        let handshakeData = try await receiveExact(connection, count: STWMTProtoHandshake.handshakeLen)
        let handshake = [UInt8](handshakeData)

        guard let result = STWMTProtoHandshake.tryParse(handshake, secret: config.secretBytes) else {
            await statsActor.update { $0.connectionsBad += 1 }
            logger.debug("Bad handshake (wrong secret or proto)")
            // Drain remaining data to look like a normal connection
            _ = try? await receiveData(connection, maxLength: 4096)
            return
        }

        let relayInit = STWMTProtoHandshake.generateRelayInit(protoTag: result.protoTag, dcIdx: result.dcIdx)

        // Build client cipher pair (decrypt from client, encrypt to client)
        let cltDecIV = result.clientDecIV
        let cltDecKey = result.generateClientDecKey(secret: config.secretBytes)
        let cltEncIV = result.clientEncIV
        let cltEncKey = result.generateClientEncKey(secret: config.secretBytes)
        
        let cltDecryptor = STWAESCTR(key: cltDecKey, iv: cltDecIV)
        let cltEncryptor = STWAESCTR(key: cltEncKey, iv: cltEncIV)

        // Fast-forward past 64-byte init
        _ = cltDecryptor.process(STWMTProtoHandshake.zeroArr64)

        // Relay side: standard obfuscation (no secret hash)
        let relayEncKey = Array(relayInit[STWMTProtoHandshake.skipLen ..< STWMTProtoHandshake.skipLen + STWMTProtoHandshake.preKeyLen])
        let relayEncIV = Array(relayInit[STWMTProtoHandshake.skipLen + STWMTProtoHandshake.preKeyLen ..< STWMTProtoHandshake.skipLen + STWMTProtoHandshake.preKeyLen + STWMTProtoHandshake.ivLen])

        let relayDecPrekeyIV = Array(relayInit[STWMTProtoHandshake.skipLen ..< STWMTProtoHandshake.skipLen + STWMTProtoHandshake.preKeyLen + STWMTProtoHandshake.ivLen].reversed())
        let relayDecKey = Array(relayDecPrekeyIV[0..<STWMTProtoHandshake.keyLen])
        let relayDecIV = Array(relayDecPrekeyIV[STWMTProtoHandshake.keyLen...])

        let tgEncryptor = STWAESCTR(key: relayEncKey, iv: relayEncIV)
        let tgDecryptor = STWAESCTR(key: relayDecKey, iv: relayDecIV)
        _ = tgEncryptor.process(STWMTProtoHandshake.zeroArr64)

        // Try connecting via WebSocket
        let mediaTag = result.media ? "m" : ""
        logger.info("Handshake ok: DC\(result.dcId)\(mediaTag)")

        guard let targetIP = config.dcRedirects[result.dcId] else {
            // DC not in config — try TCP fallback
            if let fallbackIP = STWConstants.dcDefaultIP[result.dcId] {
                logger.info("DC\(result.dcId) not in config, TCP fallback to \(fallbackIP):443")
                try await tcpFallback(
                    connection: connection, dst: fallbackIP, port: 443,
                    relayInit: relayInit,
                    cltDecryptor: cltDecryptor, cltEncryptor: cltEncryptor,
                    tgEncryptor: tgEncryptor, tgDecryptor: tgDecryptor
                )
            } else {
                logger.warning("DC\(result.dcId) — no fallback available")
            }
            return
        }

        let domains = result.generateWsDomains(overrides: config.dcOverrides)

        var ws: RawWebSocket? = nil
        for domain in domains {
            logger.info("DC\(result.dcId)\(mediaTag) -> wss://\(domain)/apiws via \(targetIP)")
            do {
                ws = try await RawWebSocket.connect(ip: targetIP, domain: domain, timeout: 10)
                break
            } catch let error as WsHandshakeError where error.isRedirect {
                logger.warning("DC\(result.dcId)\(mediaTag) got \(error.statusCode) redirect")
                continue
            } catch {
                await statsActor.update { $0.wsErrors += 1 }
                logger.warning("DC\(result.dcId)\(mediaTag) WS connect failed: \(error)")
            }
        }

        guard let activeWS = ws else {
            // WS failed — TCP fallback
            let fallbackIP = STWConstants.dcDefaultIP[result.dcId] ?? targetIP
            logger.info("DC\(result.dcId)\(mediaTag) WS failed, TCP fallback to \(fallbackIP):443")
            try await tcpFallback(
                connection: connection, dst: fallbackIP, port: 443,
                relayInit: relayInit,
                cltDecryptor: cltDecryptor, cltEncryptor: cltEncryptor,
                tgEncryptor: tgEncryptor, tgDecryptor: tgDecryptor
            )
            return
        }

        await statsActor.update { $0.connectionsWS += 1 }

        // Build splitter
        let splitter = STWMsgSplitController(relayInit: relayInit, proto: result.protoTag)

        // Send relay init to Telegram
        try await activeWS.send(Data(relayInit))

        // Bridge: client TCP <-> Telegram WS with re-encryption
        try await bridgeWSReencrypt(
            connection: connection, ws: activeWS,
            cltDecryptor: cltDecryptor, cltEncryptor: cltEncryptor,
            tgEncryptor: tgEncryptor, tgDecryptor: tgDecryptor,
            splitter: splitter
        )
    }

    // MARK: - Bridge WS

    private func bridgeWSReencrypt(
        connection: NWConnection, ws: RawWebSocket,
        cltDecryptor: STWAESCTR, cltEncryptor: STWAESCTR,
        tgEncryptor: STWAESCTR, tgDecryptor: STWAESCTR,
        splitter: STWMsgSplitController
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // TCP -> WS (client to Telegram)
            group.addTask { [weak self] in
                guard let self else { return }
                do {
                    while true {
                        let chunk = try await self.receiveData(connection, maxLength: 65536)
                        guard !chunk.isEmpty else { break }

                        await self.statsActor.update { $0.bytesUp += UInt64(chunk.count) }

                        let plain = cltDecryptor.process(chunk)
                        let encrypted = tgEncryptor.process(plain)

                        let parts = splitter.split(encrypted)
                        if parts.isEmpty { continue }

                        if parts.count > 1 {
                            try await ws.sendBatch(parts)
                        } else {
                            try await ws.send(parts[0])
                        }
                    }
                } catch {
                    // Connection closed
                }
                await ws.close()
            }

            // WS -> TCP (Telegram to client)
            group.addTask { [weak self] in
                guard let self else { return }
                do {
                    while true {
                        guard let data = try await ws.recv() else { break }

                        await self.statsActor.update { $0.bytesDown += UInt64(data.count) }

                        let plain = tgDecryptor.process(data)
                        let encrypted = cltEncryptor.process(plain)

                        try await self.sendData(connection, data: encrypted)
                    }
                } catch {
                    // Connection closed
                }
                connection.cancel()
            }

            // Wait for either direction to finish
            try await group.next()
            group.cancelAll()
        }
    }

    // MARK: - TCP Fallback

    private func tcpFallback(
        connection: NWConnection, dst: String, port: Int,
        relayInit: [UInt8],
        cltDecryptor: STWAESCTR, cltEncryptor: STWAESCTR,
        tgEncryptor: STWAESCTR, tgDecryptor: STWAESCTR
    ) async throws {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(dst),
            port: NWEndpoint.Port(rawValue: UInt16(port))!
        )
        let remote = NWConnection(to: endpoint, using: params)
        remote.start(queue: DispatchQueue.global(qos: .userInitiated))

        try await waitForReady(remote)

        // Send relay init
        try await sendData(remote, data: Data(relayInit))

        await statsActor.update { $0.connectionsTCPFallback += 1 }

        // Bridge TCP <-> TCP with re-encryption
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Client -> Remote
            group.addTask { [weak self] in
                guard let self else { return }
                do {
                    while true {
                        let data = try await self.receiveData(connection, maxLength: 65536)
                        guard !data.isEmpty else { break }
                        await self.statsActor.update { $0.bytesUp += UInt64(data.count) }
                        let plain = cltDecryptor.process(data)
                        let enc = tgEncryptor.process(plain)
                        try await self.sendData(remote, data: enc)
                    }
                } catch {}
                remote.cancel()
            }

            // Remote -> Client
            group.addTask { [weak self] in
                guard let self else { return }
                do {
                    while true {
                        let data = try await self.receiveData(remote, maxLength: 65536)
                        guard !data.isEmpty else { break }
                        await self.statsActor.update { $0.bytesDown += UInt64(data.count) }
                        let plain = tgDecryptor.process(data)
                        let enc = cltEncryptor.process(plain)
                        try await self.sendData(connection, data: enc)
                    }
                } catch {}
                connection.cancel()
            }

            try await group.next()
            group.cancelAll()
        }
    }

    // MARK: - NWConnection helpers

    private func waitForReady(_ connection: NWConnection) async throws {
        if connection.state == .ready { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    cont.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    cont.resume(throwing: CancellationError())
                default:
                    break
                }
            }
        }
    }

    private func receiveExact(_ connection: NWConnection, count: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let data, data.count == count {
                    cont.resume(returning: data)
                } else {
                    cont.resume(throwing: RawWebSocket.ConnectionError.closed)
                }
            }
        }
    }

    private func receiveData(_ connection: NWConnection, maxLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    cont.resume(returning: data)
                } else if isComplete {
                    cont.resume(returning: Data())
                } else {
                    cont.resume(throwing: RawWebSocket.ConnectionError.closed)
                }
            }
        }
    }

    private func sendData(_ connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            })
        }
    }
}

// MARK: - Stats Actor

actor StatsActor {
    private var stats = ProxyStats()
    
    func getStats() -> ProxyStats {
        return stats
    }
    
    func update(_ update: (inout ProxyStats) -> Void) {
        update(&stats)
    }
}
