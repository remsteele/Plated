import Foundation

enum UnitConverter {
    private static let poundsPerKilogram = 2.2046226218
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

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
        return formattedNumber(value)
    }

    static func formattedVolume(_ pounds: Double, unit: String) -> String {
        let value = displayWeight(from: pounds, unit: unit)
        return formattedNumber(value)
    }

    static func formattedNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
