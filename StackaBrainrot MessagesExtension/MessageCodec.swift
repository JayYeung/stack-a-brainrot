//
//  MessageCodec.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import Foundation
import Messages

enum MessageCodec {

    // MARK: - Public

    static func makeMessage(state: GameState, session: MSSession) -> MSMessage {
        let message = MSMessage(session: session)

        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "s", value: encodeStateToBase64URL(state))
        ]
        message.url = comps.url

        let layout = MSMessageTemplateLayout()
        layout.caption = "Stack a Brainrot"

        switch state.phase {
        case .pending:
            layout.subcaption = "Tap to start dropping!"
        case .active:
            layout.subcaption = "Brainrot: \(state.count)"
        case .finished:
            layout.subcaption = "Game Over - Tap to see results"
        }

        message.layout = layout
        return message
    }

    static func decodeState(from message: MSMessage) -> GameState? {
        guard let url = message.url,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems,
              let s = items.first(where: { $0.name == "s" })?.value
        else { return nil }

        return decodeStateFromBase64URL(s)
    }

    // MARK: - Encoding helpers

    private static func encodeStateToBase64URL(_ state: GameState) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = []
        let data = (try? enc.encode(state)) ?? Data()
        return base64URLEncode(data)
    }

    private static func decodeStateFromBase64URL(_ s: String) -> GameState? {
        guard let data = base64URLDecode(s) else { return nil }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var b64 = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let pad = 4 - (b64.count % 4)
        if pad < 4 { b64 += String(repeating: "=", count: pad) }

        return Data(base64Encoded: b64)
    }
}
