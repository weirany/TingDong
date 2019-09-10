import Foundation

class Util {
    static func intArrayToString(arr: [Int]) -> String {
        return arr.count == 0 ? "" : arr.map{String($0)}.joined(separator:"|")
    }
    
    static func stringToIntArray(str: String) -> [Int] {
        return str == "" ? [] : str.split(separator: "|").map { Int(String($0))! }
    }
}
