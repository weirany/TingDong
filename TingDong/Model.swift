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
	
public class Word {
    let wordId: Int
    let word: String
    let translation: String
    
    init(record: CKRecord) {
        self.wordId = record["wordId"] as! Int
        self.word = record["word"] as! String
        self.translation = record["translation"] as! String
    }
}

public class TouchedOrNot {
    let touched: String
    let untouched: String
    
    init(record: CKRecord) {
        self.touched = record["touched"] as! String
        self.untouched = record["untouched"] as! String
    }
    
    init() {
        self.touched = ""
        self.untouched = (2...StateCount.max).reduce("1") { numStr, num in "\(numStr)|\(num)" }
    }
    
    var randomFWordId: Int {
        guard untouched != "" else {
            fatalError("trying to get a random F state word while no more untouched words?!")
        }
        let untouchedList = untouched.split(separator: "|")
        let ran = Int.random(in: 0..<untouchedList.count)
        return Int(untouchedList[ran])!
    }
}
