//
//  ActivitySheet.swift
//  Iron
//
//  Created by Karim Abou Zeid on 02.04.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct ActivitySheet: View {
    @Binding var activityItems: [Any]?
    var applicationActivities: [UIActivity]?
    
    var body: some View {
        activityItems.map { _ in
            ActivityViewController(activityItems: $activityItems, applicationActivities: applicationActivities)
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    @Binding var activityItems: [Any]?
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewControllerHost {
        let result = UIActivityViewControllerHost()
        result.activityItems = activityItems ?? []
        result.applicationActivities = applicationActivities
        result.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            self.activityItems = nil
        }
        return result
    }

    func updateUIViewController(_ uiViewController: UIActivityViewControllerHost, context: Context) {
    }
}

private class UIActivityViewControllerHost: UIViewController {
    var activityItems = [Any]()
    var applicationActivities: [UIActivity]?
    var completionWithItemsHandler: UIActivityViewController.CompletionWithItemsHandler? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // This host sits in a full-screen overlay only to present the share sheet. Keep it clear and
        // pass touches through, so the screen behind stays visible instead of going black.
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentActivityViewController()
    }

    private func presentActivityViewController() {
        guard presentedViewController == nil else { return }
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)

        activityViewController.completionWithItemsHandler = completionWithItemsHandler
        // Anchor the popover to the bottom center on iPad; ignored on iPhone (bottom sheet).
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        self.present(activityViewController, animated: true, completion: nil)
    }
}
