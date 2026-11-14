import SwiftUI
import UIKit

/// SwiftUI blocks a dirty sheet's swipe, but does not expose the attempted
/// dismissal. Observe UIKit's attempt callback so Back, Close, and swipe share a warning.
/// Installed while exit is guarded; restore SwiftUI's delegate when the guard leaves.
struct SheetDismissalObserver: UIViewControllerRepresentable {
    var onAttempt: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onAttempt: onAttempt) }

    func makeUIViewController(context: Context) -> ObserverController {
        let controller = ObserverController()
        controller.observer = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: ObserverController, context: Context) {
        context.coordinator.onAttempt = onAttempt
        // Presentation may be attached after this SwiftUI update.
        DispatchQueue.main.async { controller.observePresentation() }
    }

    static func dismantleUIViewController(_ controller: ObserverController, coordinator: Coordinator) {
        controller.observer = nil
        coordinator.detach()
    }

    final class ObserverController: UIViewController {
        weak var observer: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            observePresentation()
        }

        func observePresentation() {
            var host: UIViewController = self
            while let parent = host.parent { host = parent }
            if let presentation = host.presentationController { observer?.observe(presentation) }
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var onAttempt: () -> Void
        private weak var presentation: UIPresentationController?
        private weak var previous: (any UIAdaptivePresentationControllerDelegate)?

        init(onAttempt: @escaping () -> Void) { self.onAttempt = onAttempt }

        func observe(_ controller: UIPresentationController) {
            if presentation !== controller { detach() }
            presentation = controller
            if controller.delegate !== self {
                previous = controller.delegate
                controller.delegate = self
            }
        }

        func detach() {
            if presentation?.delegate === self { presentation?.delegate = previous }
            presentation = nil
            previous = nil
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            false
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt()
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            previous?.presentationControllerWillDismiss?(presentationController)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            previous?.presentationControllerDidDismiss?(presentationController)
        }
    }
}
