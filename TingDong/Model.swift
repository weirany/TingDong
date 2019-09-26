import Foundation
import CloudKit

public enum WordState: Int {
    case f = -1, a = 0, b, c, d, e
}

public enum ABTesting: Int {
    case a = 1, b = 2
}

public class UserConfig {
    var userId: String!
    var aOrB: ABTesting!

    init(record: CKRecord) {
        self.userId = (record["userId"] as! String)
        self.aOrB = ABTesting(rawValue: (record["aOrB"] as! Int))
    }
    
    init(userId: String) {
        self.userId = userId
        self.aOrB = ABTesting(rawValue: Int.random(in: 1...2))
    }
}

//○ A: Incorrect/Correct: learned (初记)
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
    var totalAttempts: Int
    
    init(record: CKRecord) {
        self.a = record["a"] as! Int
        self.b = record["b"] as! Int
        self.c = record["c"] as! Int
        self.d = record["d"] as! Int
        self.e = record["e"] as! Int
        self.totalAttempts = record["totalAttempts"] as! Int
    }
    
    init() {
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = 0
        self.e = 0
        self.totalAttempts = 0
    }
    
    class var max: Int { return 42231 }

    var sum: Int { return a + b + c + d + e }
    var f: Int { return StateCount.max - sum}
    
    // return new state
    func update(currentState: WordState, hasCorrectAnswer: Bool) -> WordState {
        totalAttempts += 1
        switch currentState {
        case .f:
            e += 1
            return .e
        case .a:
            a -= 1
            if hasCorrectAnswer {
                c += 1
                return .c
            }
            else {
                b += 1
                return .b
            }
        case .b:
            b -= 1
            if hasCorrectAnswer {
                a += 1
                return .a
            }
            else {
                d += 1
                return .d
            }
        case .c:
            c -= 1
            if hasCorrectAnswer {
                c += 1
                return .c
            }
            else {
                b += 1
                return .b
            }
        case .d:
            d -= 1
            if hasCorrectAnswer {
                a += 1
                return .a
            }
            else {
                d += 1
                return .d
            }
        case .e:
            e -= 1
            if hasCorrectAnswer {
                a += 1
                return .a
            }
            else {
                d += 1
                return .d
            }
        }
    }
}

public class AEWord {
    let dueAt: Date
    let enqueueAt: Date
    let state: WordState
    let wordId: Int
    let record: CKRecord?
    
    init(dueAt: Date? = nil, enqueueAt: Date? = nil, state: WordState? = nil, record: CKRecord? = nil, wordId: Int) {
        self.dueAt = dueAt ?? Util.calculateDueAt(enqueueAt: Date())
        self.enqueueAt = enqueueAt ?? Date()
        self.state = state ?? WordState.f
        self.record = record
        self.wordId = wordId
    }
    
    init(record: CKRecord) {
        self.dueAt = record["dueAt"] as! Date
        self.enqueueAt = record["enqueueAt"] as! Date
        self.state = WordState(rawValue: (record["state"] as! Int))!
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
        let list = touched.count < 4 ? untouched : touched
        
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
    
    // if state is F state, means it's a new word
    func update(aeword: AEWord) {
        if aeword.state == .f {
            touched.append(aeword.wordId)
            if let index = untouched.firstIndex(of: aeword.wordId) {
                untouched.remove(at: index)
            }
            touchedStr = Util.intArrayToString(arr: touched)
            untouchedStr = Util.intArrayToString(arr: untouched)
        }
    }
}
