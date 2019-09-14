import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!

    // local
    var latestStateCount: StateCount!
    var tenDayAgoStateCount: StateCount!
    var hundredDayAgoStateCount: StateCount!
    var touchedOrNot: TouchedOrNot!

    var nextWord: Word!
    var nextAEWord: AEWord!
    var nextThreeOtherWordTrans: [String]!
    var correctAnswerIndex = 0
    var answered = false

    // UI outlets
    @IBOutlet weak var master0: UILabel!
    @IBOutlet weak var learned0: UILabel!
    @IBOutlet weak var untouched0: UILabel!
    @IBOutlet weak var master10: UILabel!
    @IBOutlet weak var learned10: UILabel!
    @IBOutlet weak var untouched10: UILabel!
    @IBOutlet weak var master100: UILabel!
    @IBOutlet weak var learned100: UILabel!
    @IBOutlet weak var untouched100: UILabel!

    @IBOutlet weak var transLabel1: UILabel!
    @IBOutlet weak var transLabel2: UILabel!
    @IBOutlet weak var transLabel3: UILabel!
    @IBOutlet weak var transLabel4: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // initialize ui
        resetUIGetReadyForNextWord()
        
        // events
        var tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
        transLabel1.addGestureRecognizer(tap)
        tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
        transLabel2.addGestureRecognizer(tap)
        tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
        transLabel3.addGestureRecognizer(tap)
        tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
        transLabel4.addGestureRecognizer(tap)

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
            self.transitionToNextWord()
        }
    }
    
    func updateUIStateCounts() {
        master0.text = String(latestStateCount.c)
        learned0.text = String(latestStateCount.a)
        untouched0.text = String(latestStateCount.f)
        master10.text = String(tenDayAgoStateCount.c)
        learned10.text = String(tenDayAgoStateCount.a)
        untouched10.text = String(tenDayAgoStateCount.f)
        master100.text = String(hundredDayAgoStateCount.c)
        learned100.text = String(hundredDayAgoStateCount.a)
        untouched100.text = String(hundredDayAgoStateCount.f)
    }
    
    func transitionToNextWord() {
        self.readNextWord { (word, aeword) in
            self.nextWord = word
            self.nextAEWord = aeword
            self.readNextThreeOtherWordDefs {
                DispatchQueue.main.async {
                    // randomize answers
                    self.correctAnswerIndex = Int.random(in: 0..<4)
                    var trans = self.nextThreeOtherWordTrans!
                    trans.insert(self.nextWord!.translation, at: self.correctAnswerIndex)
                    self.transLabel1.text = trans[0]
                    self.transLabel2.text = trans[1]
                    self.transLabel3.text = trans[2]
                    self.transLabel4.text = trans[3]
                    // ready to answer
                    self.answered = false
                }
            }
        }
    }
    
    func handleAnswer(hasCorrectAnswer: Bool, completion: @escaping () -> Void) {
        // update touchOrNot (local then cloud)
        touchedOrNot.update(aeword: nextAEWord)
        if nextAEWord.state == -1 {
            writeTouchedOrNotToCloud { () in
                // update state count (local then cloud), then update UI. 
                let newState = self.latestStateCount.update(currentState: self.nextAEWord.state, hasCorrectAnswer: hasCorrectAnswer)
                self.writeLatestStateCountToCloud { () in
                    // update AEWord (cloud only)
                    self.writeLatestAEWordToCloud(newState: newState) { () in
                        completion()
                    }
                }
                self.updateUIStateCounts()
            }
        }
    }
    
    func initAllLocalVarsFromCloud(completion: @escaping () -> Void) {
        readStateCountFromCloud(0) { (record) in
            if let record = record {
                self.latestStateCount = StateCount(record: record)
                self.readStateCountFromCloud(10) { (record) in
                    if let record = record {
                        self.tenDayAgoStateCount = StateCount(record: record)
                    }
                    else {
                        self.tenDayAgoStateCount = StateCount()
                    }
                    self.readStateCountFromCloud(100) { (record) in
                        if let record = record {
                            self.hundredDayAgoStateCount = StateCount(record: record)
                        }
                        else {
                            self.hundredDayAgoStateCount = StateCount()
                        }

                        DispatchQueue.main.async {
                            self.updateUIStateCounts()
                        }
                        self.readTouchedOrNotFromCloud { (result) in
                            self.touchedOrNot = result
                            completion()
                        }
                    }
                }
            }
            else {
                fatalError("Got nil while getting latest State Count from cloud")
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
        if (self.latestStateCount.c * 4 > self.latestStateCount.sum && (self.latestStateCount.sum < StateCount.max)) {
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
                    if self.latestStateCount.sum < StateCount.max {
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
        var result: AEWord? = nil
        let pred = anyAToEWord ? NSPredicate(value: true) : NSPredicate(format: "(state == %d) AND (dueAt < %@)", stateToPickNext, NSDate())
        let query = CKQuery(recordType: "AEWord", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        let sort = NSSortDescriptor(key: "dueAt", ascending: true)
        query.sortDescriptors = [sort]
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = AEWord(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            else {
                completion(result)
            }
        }
        privateDB.add(queryOp)
    }
    
    func readWordFromCloud(wordId: Int, completion: @escaping (_ word: Word) -> Void) {
        var result: Word? = nil
        let pred = NSPredicate(format: "wordId == %d", wordId)
        let query = CKQuery(recordType: "Word", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = Word(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            else if let result = result {
                completion(result)
            }
            else {
                fatalError("failed to read wordId:\(wordId) from cloud!")
            }
        }
        publicDB.add(queryOp)
    }
    
    func readTouchedOrNotFromCloud(completion: @escaping (_ result: TouchedOrNot) -> Void) {
        var result: TouchedOrNot? = nil
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "TouchedOrNot", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = TouchedOrNot(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            else if let result = result {
                completion(result)
            }
            else {
                fatalError("Got nil while getting TouchedOrNot from cloud")
            }
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

    func readStateCountFromCloud(_ numOfDaysAgo: Int, completion: @escaping (_ record: CKRecord?) -> Void) {
        let queryDate = Calendar.current.date(byAdding: .day, value: -numOfDaysAgo, to: Date())!
        let pred = numOfDaysAgo == 0 ? NSPredicate(value: true) : NSPredicate(format: "creationDate < %@", queryDate as NSDate)
        let query = CKQuery(recordType: "StateCount", predicate: pred)
        let sort = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [sort]
        let queryOp = CKQueryOperation(query: query)
        var result: CKRecord? = nil
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = record
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            else {
                completion(result)
            }
        }
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasStateCountsInitialized) {
            publicDB.add(queryOp)
        }
        else {
            self.latestStateCount = StateCount()
            self.writeLatestStateCountToCloud {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasStateCountsInitialized)
                self.publicDB.add(queryOp)
            }
        }
    }
    
    func writeLatestStateCountToCloud(completion: @escaping () -> Void) {
        let record = CKRecord(recordType: "StateCount")
        record.setValue(self.latestStateCount.a, forKey: "a")
        record.setValue(self.latestStateCount.b, forKey: "b")
        record.setValue(self.latestStateCount.c, forKey: "c")
        record.setValue(self.latestStateCount.d, forKey: "d")
        record.setValue(self.latestStateCount.e, forKey: "e")
        record.setValue(self.latestStateCount.totalAttempts, forKey: "totalAttempts")
        publicDB.save(record) { (rec, error) in
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
    
    @objc
    func answerTapped(sender:UITapGestureRecognizer) {
        if answered {
            resetUIGetReadyForNextWord()
            transitionToNextWord()
        }
        else {
            answered = true
            var tappedIndex = sender.view?.tag
            let animation = {
                self.transLabel1.alpha = self.transLabel1.tag == self.correctAnswerIndex ? 1 : 0
                self.transLabel2.alpha = self.transLabel2.tag == self.correctAnswerIndex ? 1 : 0
                self.transLabel3.alpha = self.transLabel3.tag == self.correctAnswerIndex ? 1 : 0
                self.transLabel4.alpha = self.transLabel4.tag == self.correctAnswerIndex ? 1 : 0
            }
            UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut,
                           animations: animation ) { (finished: Bool) in
            }
        }
    }
    
    func resetUIGetReadyForNextWord() {
        transLabel1.text = ""
        transLabel2.text = ""
        transLabel3.text = ""
        transLabel4.text = ""
        
        transLabel1.alpha = 1
        transLabel2.alpha = 1
        transLabel3.alpha = 1
        transLabel4.alpha = 1
    }
}
