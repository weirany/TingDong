import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!

    // local
    var stateCount: StateCount!
    var touchedOrNot: TouchedOrNot!

    var nextWord: Word!
    var nextAEWord: AEWord!
    var nextThreeOtherWordTrans: [String]!
    var correctAnswerIndex = 0

    // UI outlets
    @IBOutlet weak var wordEnText: UILabel!
    @IBOutlet weak var transLabel1: UILabel!
    @IBOutlet weak var transLabel2: UILabel!
    @IBOutlet weak var transLabel3: UILabel!
    @IBOutlet weak var transLabel4: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let container = CKContainer.default()
        publicDB = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase

        container.accountStatus { (status, error) in
            if let err = error {
                print(err.localizedDescription)
            }
            else {
                switch status {
                case .available:
                    print("available")
                default:
                    print("not avaliable")
                }
            }
        }
        
        initAllLocalVarsFromCloud {
            self.readNextWord { (word, aeword) in
                self.nextWord = word
                self.nextAEWord = aeword
                self.readNextThreeOtherWordDefs {
                    DispatchQueue.main.async {
                        // randomize answers
                        self.correctAnswerIndex = Int.random(in: 0..<4)
                        var trans = self.nextThreeOtherWordTrans!
                        trans.insert(self.nextWord!.translation, at: self.correctAnswerIndex)
                        self.wordEnText.text = self.nextWord!.word
                        self.transLabel1.text = trans[0]
                        self.transLabel2.text = trans[1]
                        self.transLabel3.text = trans[2]
                        self.transLabel4.text = trans[3]
                    }
                }
            }
        }
    }
    
    func handleAnswer(hasCorrectAnswer: Bool, completion: @escaping () -> Void) {
        // update touchOrNot (local then cloud)
        touchedOrNot.update(aeword: nextAEWord)
        if nextAEWord.state == -1 {
            writeTouchedOrNotToCloud { () in
                // update state count (local then cloud)
                let newState = self.stateCount.update(currentState: self.nextAEWord.state, hasCorrectAnswer: hasCorrectAnswer)
                self.writeLatestStateCountToCloud { () in
                    // update AEWord (cloud only)
                    self.writeLatestAEWordToCloud(newState: newState) { () in
                        // update history (cloud only)
                        self.writeLatestHistoryToCloud(toState: newState) { () in
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    func initAllLocalVarsFromCloud(completion: @escaping () -> Void) {
        readLatestStateCountFromCloud {
            self.readTouchedOrNotFromCloud {
                completion()
            }
        }
    }
    
    func readNextThreeOtherWordDefs(completion: @escaping () -> Void) {
        guard nextWord != nil else {
            fatalError("trying to read other 3 words while nextWord is nil?!")
        }
        
        // reset first
        nextThreeOtherWordTrans = []
        
        let threeIds = touchedOrNot.otherThreeRandomWordIds(excludeWordId: nextWord.wordId)
        readWordFromCloud(wordId: threeIds[0]) { (word) in
            self.nextThreeOtherWordTrans.append(word.translation)
            self.readWordFromCloud(wordId: threeIds[1]) { (word) in
                self.nextThreeOtherWordTrans.append(word.translation)
                self.readWordFromCloud(wordId: threeIds[2]) { (word) in
                    self.nextThreeOtherWordTrans.append(word.translation)
                    completion()
                }
            }
        }
    }
    
    func readNextWord(completion: @escaping (_ word: Word, _ aeword: AEWord) -> Void) {
        // if Cx4 > Sum(touched) and F is not empty: get from F.
        if (self.stateCount.c * 4 > self.stateCount.sum && (self.stateCount.sum < StateCount.max)) {
            let fWordId = touchedOrNot.randomFWordId
            self.readWordFromCloud(wordId: fWordId) { (word) in
                completion(word, AEWord(wordId: fWordId))
            }
        }
        else {
            readNextAToEFromCloud(anyAToEWord: false) { (aeword) in
                if let aeword = aeword {
                    self.readWordFromCloud(wordId: aeword.wordId) { (word) in
                        completion(word, aeword)
                    }
                }
                else {
                    if self.stateCount.sum < StateCount.max {
                        let fWordId = self.touchedOrNot.randomFWordId
                        self.readWordFromCloud(wordId: fWordId) { (word) in
                            completion(word, AEWord(wordId: fWordId))
                        }
                    }
                    else {
                        self.readNextAToEFromCloud(anyAToEWord: true) { (aeword) in
                            if let aeword = aeword {
                                self.readWordFromCloud(wordId: aeword.wordId) { (word) in
                                    completion(word, aeword)
                                }
                            }
                            else {
                                fatalError("no more untouched words, but failed to read any word id from A to E!")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func readNextAToEFromCloud(anyAToEWord: Bool, completion: @escaping (_ aeword: AEWord?) -> Void) {
        //    - How frequently each category got picked
        //    ○ D: 1| 0
        //    ○ C: 2 | 1, 2
        //    ○ E: 3 | 3, 4, 5
        //    ○ B: 5 | 6, 7, 8, 9, 10
        //    ○ A: 5 | 11, 12, 13, 14, 15
        let ran = Int.random(in: 0..<16)
        var stateToPickNext = 0
        switch ran {
        case 0: stateToPickNext = 4
        case 1, 2: stateToPickNext = 3
        case 3, 4, 5: stateToPickNext = 5
        case 6, 7, 8, 9, 10: stateToPickNext = 2
        case 11, 12, 13, 14, 15: stateToPickNext = 1
        default:
            fatalError("Got a random number outside of [0,15]")
        }
        
        // logic: the earliest from a given state, but it has to be dued.
        let pred = anyAToEWord ? NSPredicate(value: true) : NSPredicate(format: "(state == %d) AND (dueAt < %@)", stateToPickNext, NSDate())
        let query = CKQuery(recordType: "AEWord", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        let sort = NSSortDescriptor(key: "dueAt", ascending: true)
        query.sortDescriptors = [sort]
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            completion(AEWord(record: record))
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion(nil)
        }
        privateDB.add(queryOp)
    }
    
    func readWordFromCloud(wordId: Int, completion: @escaping (_ word: Word) -> Void) {
        var result: Word?
        let pred = NSPredicate(format: "wordId == %d", wordId)
        let query = CKQuery(recordType: "Word", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = Word(record: record)
            completion(result!)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if result == nil {
                fatalError("failed to read wordId:\(wordId) from cloud!")
            }
        }
        publicDB.add(queryOp)
    }
    
    func readTouchedOrNotFromCloud(completion: @escaping () -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "TouchedOrNot", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            self.touchedOrNot = TouchedOrNot(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if self.touchedOrNot == nil {
                fatalError("Got nil while getting TouchedOrNot from cloud")
            }
            completion()
        }
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasTouchedOrNotInitialized) {
            privateDB.add(queryOp)
        }
        else {
            self.touchedOrNot = TouchedOrNot()
            self.writeTouchedOrNotToCloud {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasTouchedOrNotInitialized)
                self.privateDB.add(queryOp)
            }
        }
    }
    
    func writeTouchedOrNotToCloud(completion: @escaping () -> Void) {
        let record = CKRecord(recordType: "TouchedOrNot")
        record.setValue(self.touchedOrNot.touchedStr, forKey: "touched")
        record.setValue(self.touchedOrNot.untouchedStr, forKey: "untouched")
        privateDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
        }
    }

    func readLatestStateCountFromCloud(completion: @escaping () -> Void) {
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "StateCount", predicate: pred)
        let sort = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [sort]
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            self.stateCount = StateCount(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if self.stateCount == nil {
                fatalError("Got nil while getting State Count from cloud")
            }
            completion()
        }
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasStateCountsInitialized) {
            privateDB.add(queryOp)
        }
        else {
            self.stateCount = StateCount()
            self.writeLatestStateCountToCloud {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasStateCountsInitialized)
                self.privateDB.add(queryOp)
            }
        }
    }
    
    func writeLatestStateCountToCloud(completion: @escaping () -> Void) {
        let record = CKRecord(recordType: "StateCount")
        record.setValue(self.stateCount.a, forKey: "a")
        record.setValue(self.stateCount.b, forKey: "b")
        record.setValue(self.stateCount.c, forKey: "c")
        record.setValue(self.stateCount.d, forKey: "d")
        record.setValue(self.stateCount.e, forKey: "e")
        privateDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
        }
    }
    
    func writeLatestAEWordToCloud(newState: Int, completion: @escaping () -> Void) {
        let record = nextAEWord.record ?? CKRecord(recordType: "AEWord")
        record.setValue(nextAEWord.newDueAt, forKey: "dueAt")
        record.setValue(nextAEWord.enqueueAt, forKey: "enqueueAt")
        record.setValue(newState, forKey: "state")
        record.setValue(nextAEWord.wordId, forKey: "wordId")
        privateDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
        }
    }
    
    func writeLatestHistoryToCloud(toState: Int, completion: @escaping () -> Void) {
        let record = CKRecord(recordType: "History")
        record.setValue(nextAEWord.state, forKey: "fromState")
        record.setValue(toState, forKey: "toState")
        record.setValue(nextAEWord.wordId, forKey: "wordId")
        publicDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
        }
    }
}
