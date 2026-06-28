import UIKit

extension TransferCurtainViewController {

    // MARK: - Pan gesture

    func setupPanGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        sheetView.addGestureRecognizer(pan)
    }

    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        let y = pan.location(in: view).y
        switch pan.state {
        case .began:
            panStartY = y
            panStartOffset = currentOffset
        case .changed:
            panVelocity = pan.velocity(in: view).y
            setOffset(panStartOffset + (y - panStartY), animated: false)
        case .ended, .cancelled:
            snapToDetent(velocity: panVelocity)
        default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TransferCurtainViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        // Only begin pan when the touch originates in the grab pill / header area.
        let point = gestureRecognizer.location(in: sheetView)
        return point.y <= headerView.frame.maxY + 10
    }
}
