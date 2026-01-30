//
//  MessageCodec.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import Foundation
import Messages

enum MessageCodec {

    static func makeMessage(state: GameState, session: MSSession) -> MSMessage {
        let message = MSMessage(session: session)

        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "gameId", value: state.gameId),
            URLQueryItem(name: "phase", value: state.phase.rawValue),
            URLQueryItem(name: "count", value: String(state.count)),
            URLQueryItem(name: "p1", value: state.player1),
            URLQueryItem(name: "p2", value: state.player2),
            URLQueryItem(name: "next", value: state.nextPlayer)
        ]
        
        message.url = comps.url

        let layout = MSMessageTemplateLayout()
        layout.caption = "Stack a Brainrot"
        
        switch state.phase {
        case .pending:
            layout.subcaption = "Invite pending (tap to Start)"
        case .active:
            layout.subcaption = "Count: \(state.count)"
        }

        message.layout = layout
        return message
    }

    static func decodeState(from message: MSMessage) -> GameState? {
        guard let url = message.url,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let items = comps.queryItems ?? []
        func v(_ name: String) -> String { items.first(where: { $0.name == name })?.value ?? "" }

        guard let phase = GamePhase(rawValue: v("phase")),
              let count = Int(v("count"))
        else { return nil }

        return GameState(
            gameId: v("gameId"),
            phase: phase,
            count: count,
            player1: v("p1"),
            player2: v("p2"),
            nextPlayer: v("next")
        )
    }
}
