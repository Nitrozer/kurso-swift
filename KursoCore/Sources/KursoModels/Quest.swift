import Foundation
import SwiftData

@Model public final class Quest {
    public var id: UUID = UUID()
    /// Jour concerne, ramene a minuit heure locale.
    public var day: Date = Date()
    /// Type de quete, sous forme de rawValue stable.
    public var kindRaw: String = ""
    public var target: Int = 0
    public var progress: Int = 0
    public var isClaimed: Bool = false

    public var isComplete: Bool { progress >= target }

    public init(day: Date = Date(), kindRaw: String = "", target: Int = 0) {
        self.day = day
        self.kindRaw = kindRaw
        self.target = target
    }
}
