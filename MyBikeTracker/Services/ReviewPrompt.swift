import Foundation

enum ReviewPrompt {
    private static let savedRidesKey = "review_prompt_saved_rides"
    private static let lastPromptKey = "review_prompt_last_date"

    static func shouldPrompt(afterSavingDistance distance: Double) -> Bool {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: savedRidesKey) + 1
        defaults.set(count, forKey: savedRidesKey)
        guard count >= 3, distance >= 2_000 else { return false }
        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(last) < 120 * 24 * 60 * 60 {
            return false
        }
        defaults.set(Date(), forKey: lastPromptKey)
        ProductAnalytics.shared.track(.reviewPrompted)
        return true
    }
}
