import Foundation
import CloudKit

public class StateCount {
    let a: Int
    let b: Int
    let c: Int
    let d: Int
    let e: Int
    
    init(record: CKRecord) {
        self.a = record["a"] as! Int
        self.b = record["b"] as! Int
        self.c = record["c"] as! Int
        self.d = record["d"] as! Int
        self.e = record["e"] as! Int
    }
    
    init() {
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = 0
        self.e = 0
    }
    
    var sum: Int { return a + b + c + d + e }
    
    class var max: Int { return 42231 }
}
	
