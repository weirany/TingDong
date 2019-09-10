import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!

    // local
    var stateCount: StateCount!
    var touchedOrNot: TouchedOrNot!

    var nextWord: Word!
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
            self.readNextWord { (word) in
                self.nextWord = word
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
    
    func handleAnswer() {
        
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
    
    func readNextWord(completion: @escaping (_ word: Word) -> Void) {
        // if Cx4 > Sum(touched) and F is not empty: get from F.
        if (self.stateCount.c * 4 > self.stateCount.sum && (self.stateCount.sum < StateCount.max)) {
            self.readWordFromCloud(wordId: touchedOrNot.randomFWordId) { (word) in
                completion(word)
            }
        }
        else {
            readNextAToEFromCloud(anyAToEWord: false) { (wordId) in
                if let wordId = wordId {
                    self.readWordFromCloud(wordId: wordId) { (word) in
                        completion(word)
                    }
                }
                else {
                    if self.stateCount.sum < StateCount.max {
                        self.readWordFromCloud(wordId: self.touchedOrNot.randomFWordId) { (word) in
                            completion(word)
                        }
                    }
                    else {
                        self.readNextAToEFromCloud(anyAToEWord: true) { (wordId) in
                            if let wordId = wordId {
                                self.readWordFromCloud(wordId: wordId) { (word) in
                                    completion(word)
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
    
    func readNextAToEFromCloud(anyAToEWord: Bool, completion: @escaping (_ wordId: Int?) -> Void) {
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
            completion(record["wordId"] as? Int)
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
            self.writeTouchedOrNot {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasTouchedOrNotInitialized)
                self.privateDB.add(queryOp)
            }
        }
    }
    
    func writeTouchedOrNot(completion: @escaping () -> Void) {
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
            self.writeLatestStateCount {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasStateCountsInitialized)
                self.privateDB.add(queryOp)
            }
        }
    }
    
    func writeLatestStateCount(completion: @escaping () -> Void) {
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
}
