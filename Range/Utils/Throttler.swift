import Foundation

/// Runs given block only once after `throttleTime`, no matter how many times the `throttle` function is called while waiting.
/// The block is stored for invocation and the last stored block will be executed.
class Throttler {
    private let throttleTime: TimeInterval
    private var isScheduled: Bool = false
    private var block: (() -> Void)?

    /// Init with given `throttleTime`.
    init(throttleTime: TimeInterval) {
        self.throttleTime = throttleTime
    }

    /// The throttle should be executed on main thread and runs the block on the main thread too
    func throttle(block: @escaping () -> Void) {
        self.block = block
        guard isScheduled == false else { return }
        isScheduled = true
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + throttleTime) { [weak self] in
            guard let self = self else { return }
            self.block?()
            self.block = nil
            self.isScheduled = false
        }
    }
}
