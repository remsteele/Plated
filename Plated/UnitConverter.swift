import Foundation

enum UnitConverter {
    private static let poundsPerKilogram = 2.2046226218

    static func displayWeight(from pounds: Double, unit: String) -> Double {
        if unit.lowercased() == "kg" {
            return pounds / poundsPerKilogram
        }
        return pounds
    }

    static func storedWeight(from display: Double, unit: String) -> Double {
        if unit.lowercased() == "kg" {
            return display * poundsPerKilogram
        }
        return display
    }

    static func formattedWeight(_ pounds: Double, unit: String) -> String {
        let value = displayWeight(from: pounds, unit: unit)
        return String(format: "%.1f", value)
    }
}
