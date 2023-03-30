import Foundation

/// Runs given block once after `delayTime`. If `delay` is called again during the `delayTime` the delay will be applied again.
/// The delayed block can be cancelled.
/// The block is stored for invocation and the last stored block will be executed.
class Delayer {
    private let delayTime: TimeInterval
    /// Currently delayed block
    private var workItem: DispatchWorkItem?

    /// Init with given `delayTime`.
    init(delayTime: TimeInterval) {
        self.delayTime = delayTime
    }

    /// Cancel last delayed block
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    /// The delay should be executed on main thread and runs the block on the main thread too
    func delay(block: @escaping () -> Void) {
        // cancel any currently delated block
        cancel()

        // schedule new work item with a given block
        let newWorkItem = DispatchWorkItem {
            block()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: newWorkItem)
        workItem = newWorkItem
    }
}
