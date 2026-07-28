//
//  SwipeTabView.swift
//  Forge
//
//  Reliable horizontally-swipeable pager backed by UIPageViewController (the canonical
//  Apple "Interfacing with UIKit" pattern) — SwiftUI's paged TabView / ScrollView paging
//  don't register swipes through NavigationView/List. Child controllers are built once in
//  the coordinator (state preserved), forced dark, with a bottom safe-area inset so content
//  clears the floating dock while still rendering behind it (so the dock's glass blurs).
//

import SwiftUI
import UIKit

struct SwipeTabView: UIViewControllerRepresentable {
    @Binding var selection: Int
    var bottomInset: CGFloat
    var pages: [AnyView]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .clear
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let controllers = context.coordinator.controllers
        guard controllers.indices.contains(selection) else { return }
        let currentIndex = pager.viewControllers?.first.flatMap { controllers.firstIndex(of: $0) }
        guard currentIndex != selection else { return }
        pager.setViewControllers(
            [controllers[selection]],
            direction: (currentIndex ?? 0) <= selection ? .forward : .reverse,
            animated: currentIndex != nil
        )
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SwipeTabView
        let controllers: [UIViewController]

        init(_ parent: SwipeTabView) {
            self.parent = parent
            controllers = parent.pages.map { page in
                let host = UIHostingController(rootView: page)
                host.view.backgroundColor = .clear
                host.overrideUserInterfaceStyle = .dark
                host.additionalSafeAreaInsets.bottom = parent.bottomInset
                return host
            }
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let i = controllers.firstIndex(of: vc), i > 0 else { return nil }
            return controllers[i - 1]
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let i = controllers.firstIndex(of: vc), i < controllers.count - 1 else { return nil }
            return controllers[i + 1]
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let current = pvc.viewControllers?.first, let i = controllers.firstIndex(of: current) else { return }
            if parent.selection != i {
                parent.selection = i
                Haptics.selection()
            }
        }
    }
}
