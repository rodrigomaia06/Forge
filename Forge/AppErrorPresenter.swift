//
//  AppErrorPresenter.swift
//  Forge
//
//  A calm, app-wide channel for surfacing a data error to the user instead of crashing. Low-level
//  write paths report here after rolling back, so the last saved data is preserved and the user sees
//  a plain-language message rather than a crash. The detailed technical error is only logged.
//

import Foundation

struct AppUserError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

final class AppErrorPresenter: ObservableObject {
    static let shared = AppErrorPresenter()
    private init() {}

    @Published var error: AppUserError?

    /// Present a user-facing error. Safe to call from any thread. The title and message must be plain
    /// language with no implementation details; log the technical error separately.
    func present(title: String, message: String) {
        DispatchQueue.main.async {
            // Keep the first error until dismissed, so a cascade of failures shows one calm alert.
            guard self.error == nil else { return }
            self.error = AppUserError(title: title, message: message)
        }
    }
}
