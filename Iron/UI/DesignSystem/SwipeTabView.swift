//
//  SwipeTabView.swift
//  Forge
//
//  A reliable horizontally-swipeable pager backed by UIPageViewController — SwiftUI's
//  paged TabView / ScrollView paging don't register swipes through NavigationView/List,
//  so we bridge to UIKit (which Instagram/Reddit-style apps use). Pages are built once and
//  kept alive (state preserved); `bottomInset` reserves room under the floating dock while
//  still letting content render behind it (so the dock's glass has something to blur).
//

import SwiftUI
import UIKit

struct SwipeTabView: UIViewControllerRepresentable {
    @Binding var selection: Int
    let count: Int
    let bottomInset: CGFloat
    let content: (Int) -> AnyView

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .clear
        context.coordinator.build()
        if context.coordinator.controllers.indices.contains(selection) {
            pager.setViewControllers([context.coordinator.controllers[selection]], direction: .forward, animated: false)
        }
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        guard let current = pager.viewControllers?.first,
              let currentIndex = context.coordinator.controllers.firstIndex(of: current),
              currentIndex != selection,
              context.coordinator.controllers.indices.contains(selection)
        else { return }
        pager.setViewControllers(
            [context.coordinator.controllers[selection]],
            direction: selection > currentIndex ? .forward : .reverse,
            animated: true
        )
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SwipeTabView
        var controllers: [UIViewController] = []

        init(_ parent: SwipeTabView) { self.parent = parent }

        func build() {
            controllers = (0..<parent.count).map { index in
                let host = UIHostingController(rootView: parent.content(index))
                host.view.backgroundColor = .clear
                host.overrideUserInterfaceStyle = .dark
                host.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: parent.bottomInset, right: 0)
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
