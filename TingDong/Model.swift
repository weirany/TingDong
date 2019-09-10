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
    var touchedStr: String
    var untouchedStr: String
    var touched: [Int]
    var untouched: [Int]
    
    init(record: CKRecord) {
        self.touchedStr = record["touched"] as! String
        self.untouchedStr = record["untouched"] as! String
        self.touched = Util.stringToIntArray(str: touchedStr)
        self.untouched = Util.stringToIntArray(str: untouchedStr)
    }
    
    init() {
        self.touchedStr = ""
        self.untouchedStr = (2...StateCount.max).reduce("1") { numStr, num in "\(numStr)|\(num)" }
        self.touched = Util.stringToIntArray(str: touchedStr)
        self.untouched = Util.stringToIntArray(str: untouchedStr)
    }
    
    var randomFWordId: Int {
        guard untouched.count > 0 else {
            fatalError("trying to get a random F state word while no more untouched words?!")
        }
        return untouched[Int.random(in: 0..<untouched.count)]
    }
    
    // return 3 random distinct wordIds from touched word list, not including the given wordId.
    // if touched list length < 4, then get all 3 from untouched.
    func otherThreeRandomWordIds(excludeWordId: Int) -> [Int] {
        var result: [Int] = []
        var list = touched.count < 4 ? untouched : touched
        
        while result.count < 3 {
            let temp = list[Int.random(in: 0..<list.count)]
            if temp == excludeWordId || result.contains(temp){
                continue
            }
            else {
                result.append(temp)
            }
        }
        return result
    }
}
