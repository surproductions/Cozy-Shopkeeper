import Foundation

/// Short number labels for tight UI: 950 → "950", 1,791 → "1.79K", 12,480 → "12.4K",
/// 123,456 → "123K", 2,345,678 → "2.34M". Values round *down* so a label never
/// overstates what the player has (999,999 shows "999K", not "1000K").
public enum CompactNumber {
    public static func format(_ value: Int) -> String {
        if value < 0 { return "-" + format(-value) }
        if value < 1_000 { return "\(value)" }
        let units: [(Int, String)] = [(1_000_000_000_000, "T"), (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]
        for (size, suffix) in units where value >= size {
            let whole = value / size
            let decimals = whole >= 100 ? 0 : whole >= 10 ? 1 : 2
            var scale = 1
            for _ in 0..<decimals { scale *= 10 }
            // Integer math so there is no floating-point rounding up.
            let scaled = Int((Int64(value) * Int64(scale)) / Int64(size))
            let intPart = scaled / scale
            var fraction = scaled % scale
            var digits = decimals
            while digits > 0 && fraction % 10 == 0 {
                fraction /= 10
                digits -= 1
            }
            if digits == 0 { return "\(intPart)\(suffix)" }
            let padded = String(repeating: "0", count: max(0, digits - String(fraction).count)) + String(fraction)
            return "\(intPart).\(padded)\(suffix)"
        }
        return "\(value)"
    }
}
