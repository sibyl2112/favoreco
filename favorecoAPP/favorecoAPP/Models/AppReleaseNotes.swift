//
//  AppReleaseNotes.swift
//  favorecoAPP
//

import Foundation

struct AppReleaseNote: Identifiable {
    let version: String
    let publishedAt: String
    let title: String
    let summary: String
    let highlights: [String]

    var id: String { version }
}

enum AppReleaseNotes {
    static let detailURL = URL(string: "https://ranoviqo.com/favoreco/")!

    static let entries: [AppReleaseNote] = [
        AppReleaseNote(
            version: "1.0",
            publishedAt: "2026年7月15日",
            title: "Favorecoをもっと使いやすく",
            summary: "Homeと設定を整理し、これから参加する予定を見つけやすくしました。",
            highlights: [
                "未来日に変更した参加記録をHomeの「次の予定」へ表示",
                "設定を目的別の5つの入口へ整理",
                "記録・予定・写真まわりの安定性を改善"
            ]
        )
    ]

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var current: AppReleaseNote {
        if let matching = entries.first(where: { $0.version == currentVersion }) {
            return matching
        }
        return entries.first ?? AppReleaseNote(
            version: currentVersion,
            publishedAt: "",
            title: "Favorecoを更新しました",
            summary: "使いやすさと安定性を改善しました。",
            highlights: []
        )
    }
}
