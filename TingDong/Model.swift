import Foundation
import CloudKit

//○ A: Incorrect/Correct: learned (学会)
//○ B: Correct/Incorrect: forgot
//○ C: Correct/Correct: mastered (牢记)
//○ D: Incorrect/Incorrect: not ready to learn
//○ E: incorrect/? Or correct/? (1 attempt only): learning (刚学)
public class StateCount {
    var a: Int
    var b: Int
    var c: Int
    var d: Int
    var e: Int
    
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
    
    class var max: Int { return 42231 }

    var sum: Int { return a + b + c + d + e }
    var f: Int { return StateCount.max - sum}
    
    // return new state
    func update(currentState: Int, hasCorrectAnswer: Bool) -> Int {
        switch currentState {
        case -1:    // F
            e += 1
            return 4
        case 0:     // A
            a -= 1
            if hasCorrectAnswer {
                c += 1
                return 2
            }
            else {
                b += 1
                return 1
            }
        case 1:     // B
            b -= 1
            if hasCorrectAnswer {
                a += 1
                return 0
            }
            else {
                d += 1
                return 3
            }
        case 2:     // C
            c -= 1
            if hasCorrectAnswer {
                c += 1
                return 2
            }
            else {
                b += 1
                return 1
            }
        case 3:     // D
            d -= 1
            if hasCorrectAnswer {
                a += 1
                return 0
            }
            else {
                d += 1
                return 3
            }
        case 4:     // E
            e -= 1
            if hasCorrectAnswer {
                a += 1
                return 0
            }
            else {
                d += 1
                return 3
            }
        default:
            fatalError("unknow state?! \(currentState)")
        }
    }
}

public class AEWord {
    let dueAt: Date
    let enqueueAt: Date
    let state: Int
    let wordId: Int
    let record: CKRecord?
    
    init(dueAt: Date? = nil, enqueueAt: Date? = nil, state: Int? = nil, record: CKRecord? = nil, wordId: Int) {
        self.dueAt = dueAt ?? Util.calculateDueAt(enqueueAt: Date())
        self.enqueueAt = enqueueAt ?? Date()
        self.state = state ?? -1
        self.record = record
        self.wordId = wordId
    }
    
    init(record: CKRecord) {
        self.dueAt = record["dueAt"] as! Date
        self.enqueueAt = record["enqueueAt"] as! Date
        self.state = record["state"] as! Int
        self.record = record
        self.wordId = record["wordId"] as! Int
    }
    
    var newDueAt: Date {
        return Util.calculateDueAt(enqueueAt: self.enqueueAt)
    }
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
    
    // if state is -1 (F state), means it's a new word
    func update(aeword: AEWord) {
        if aeword.state == -1 {
            touched.append(aeword.wordId)
            untouched.removeFirst(aeword.wordId)
            touchedStr = Util.intArrayToString(arr: touched)
            untouchedStr = Util.intArrayToString(arr: untouched)
        }
    }
}
