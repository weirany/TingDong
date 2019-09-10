import Foundation

class Util {
    static func intArrayToString(arr: [Int]) -> String {
        return arr.count == 0 ? "" : arr.map{String($0)}.joined(separator:"|")
    }
    
    static func stringToIntArray(str: String) -> [Int] {
        return str == "" ? [] : str.split(separator: "|").map { Int(String($0))! }
    }
    
    // logic: Now + 2 mins + Random(0, total # seconds since enqueued)
    static func calculateDueAt(enqueueAt: Date) -> Date {
        let calendar = Calendar.current
        let secSinceEnqueue = calendar.dateComponents([.second], from: enqueueAt, to: Date()).second!
        let secToAdd = 60 * 2 + Int.random(in: 0..<secSinceEnqueue)
        return calendar.date(byAdding: .second, value: secToAdd, to: Date())!
    }
}
