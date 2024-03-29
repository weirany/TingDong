import UIKit
import CloudKit
import AVFoundation
import StoreKit

// todo:
// # none

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!
    let synthesizer = AVSpeechSynthesizer()
    var speakRate: Float = 0.5
    var canResponseToTap = false
    let maxRangeOneStep: Float = 100

    // local
    var userConfig: UserConfig!
    var latestStateCount: StateCount!
    var oneDayAgoStateCount: StateCount!
    var sevenDayAgoStateCount: StateCount!
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
    @IBOutlet weak var master1: UILabel!
    @IBOutlet weak var learned1: UILabel!
    @IBOutlet weak var untouched1: UILabel!
    @IBOutlet weak var master7: UILabel!
    @IBOutlet weak var learned7: UILabel!
    @IBOutlet weak var untouched7: UILabel!

    @IBOutlet weak var transLabel1: UILabel!
    @IBOutlet weak var transLabel2: UILabel!
    @IBOutlet weak var transLabel3: UILabel!
    @IBOutlet weak var transLabel4: UILabel!
    
    @IBOutlet weak var maxRangeLabel: UILabel!
    @IBOutlet weak var maxRangeSlider: UISlider!
    
    @IBOutlet weak var playAgainButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // initialize audio session
        do { try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback) }
        catch let error as NSError {
            print("Error: Could not set audio category: \(error), \(error.userInfo)")
        }
        do { try AVAudioSession.sharedInstance().setActive(true) }
        catch let error as NSError {
            print("Error: Could not setActive to true: \(error), \(error.userInfo)")
        }

        // initialize ui
        clearAnswers()

        let container = CKContainer.default()
        publicDB = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase

        // nothing should work if iCloud is not enabled.
        checkiCloudTillWorking(container: container) {
            DispatchQueue.main.async {
                // events
                var tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
                self.transLabel1.addGestureRecognizer(tap)
                tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
                self.transLabel2.addGestureRecognizer(tap)
                tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
                self.transLabel3.addGestureRecognizer(tap)
                tap = UITapGestureRecognizer(target: self, action: #selector(MainController.answerTapped))
                self.transLabel4.addGestureRecognizer(tap)

                self.initAllLocalVarsFromCloud {
                    // time to rate the app?
                    if #available(iOS 10.3,*) {
                        if self.latestStateCount.sum > 100 {
                            DispatchQueue.main.async {
                                SKStoreReviewController.requestReview()
                            }
                        }
                    }
                    self.transitionToNextWord()
                }
            }
        }
    }
    
    func updateUIStateCounts() {
        master0.text = String(latestStateCount.c)
        learned0.text = String(latestStateCount.a)
        untouched0.text = String(latestStateCount.f)
        master1.text = String(oneDayAgoStateCount.c)
        learned1.text = String(oneDayAgoStateCount.a)
        untouched1.text = String(oneDayAgoStateCount.f)
        master7.text = String(sevenDayAgoStateCount.c)
        learned7.text = String(sevenDayAgoStateCount.a)
        untouched7.text = String(sevenDayAgoStateCount.f)
    }
    
    func transitionToNextWord() {
        self.stopSpeaking()
        self.readNextWord { (word, aeword) in
            self.nextWord = word
            self.nextAEWord = aeword
            self.readNextThreeOtherWordDefs {
                DispatchQueue.main.async {
                    self.correctAnswerIndex = Int.random(in: 0..<4)
                    var trans = self.nextThreeOtherWordTrans!
                    trans.insert(self.nextWord!.translation, at: self.correctAnswerIndex)
                    self.clearAnswers()
                    self.transLabel1.alpha = 1
                    self.transLabel2.alpha = 1
                    self.transLabel3.alpha = 1
                    self.transLabel4.alpha = 1
                    self.transLabel1.text = trans[0]
                    self.transLabel2.text = trans[1]
                    self.transLabel3.text = trans[2]
                    self.transLabel4.text = trans[3]
                    self.answered = false
                    self.speak()
                    self.playAgainButton.isEnabled = true
                    self.canResponseToTap = true
                }
            }
        }
    }
    
    @objc func speak() {
        if !self.synthesizer.isSpeaking {
            let utterance = AVSpeechUtterance(string: self.nextWord.word)
//            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = self.speakRate
            if (self.speakRate > 0.1) {
                self.speakRate -= 0.1
            }
            self.synthesizer.speak(utterance)
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        speakRate = 0.5
    }
    
    func checkiCloudTillWorking(container: CKContainer, completion: @escaping() -> Void) {
        container.accountStatus { (status, error) in
            if let err = error {
                fatalError(err.localizedDescription)
            }
            else {
                switch status {
                case .available:
                    completion()
                default:
                    DispatchQueue.main.async {
                        let alert = UIAlertController(
                            title: "iCloud is not available",
                            message: "Make sure you have signed in with your Apple ID (go to Settings => Sign in to your iPhone)",
                            preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                            self.checkiCloudTillWorking(container: container) {
                                completion()
                            }
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func handleAnswer(hasCorrectAnswer: Bool, completion: @escaping () -> Void) {
        // update touchOrNot (local then cloud)
        touchedOrNot.update(aeword: nextAEWord)
        writeTouchedOrNotToCloudIfNeeded() {
            // update state count (local then cloud), then update UI.
            let newState = self.latestStateCount.update(currentState: self.nextAEWord.state, hasCorrectAnswer: hasCorrectAnswer)
            self.writeLatestStateCountToCloud { (_) in
                // update AEWord (cloud only)
                self.writeLatestAEWordToCloud(newState: newState) { () in
                    completion()
                }
            }
            DispatchQueue.main.async {
                self.updateUIStateCounts()
            }
        }
    }
    
    func initAllLocalVarsFromCloud(completion: @escaping () -> Void) {
        readUserIdFromCloud { (userId) in
            self.readUserConfigFromCloud(userId) { (record)  in
                if let record = record {
                    self.userConfig = UserConfig(record: record)
                }
                else {
                    fatalError("Got nil while getting user config from cloud?!")
                }
                DispatchQueue.main.async {
                    self.updateSlider()
                }
                self.readStateCountFromCloud(0) { (record) in
                    if let record = record {
                        self.latestStateCount = StateCount(record: record)
                        self.readStateCountFromCloud(1) { (record) in
                            if let record = record {
                                self.oneDayAgoStateCount = StateCount(record: record)
                            }
                            else {
                                self.oneDayAgoStateCount = StateCount()
                            }
                            self.readStateCountFromCloud(7) { (record) in
                                if let record = record {
                                    self.sevenDayAgoStateCount = StateCount(record: record)
                                }
                                else {
                                    self.sevenDayAgoStateCount = StateCount()
                                }
                                
                                DispatchQueue.main.async {
                                    self.updateUIStateCounts()
                                }
                                self.readTouchedOrNotFromCloud { (record) in
                                    self.touchedOrNot = TouchedOrNot(record: record)
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
        // if Cx4 > Sum(touched) and still have untouched word in range: get from untouched in range.
        if self.latestStateCount.c * 4 > self.latestStateCount.sum,
            let wordId = self.touchedOrNot.getRandomUntouchedInRangeIfAny(config: self.userConfig) {
            self.readWordFromCloud(wordId: wordId) { (word) in
                completion(word, AEWord(wordId: wordId))
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
                    if let wordId = self.touchedOrNot.getRandomUntouchedInRangeIfAny(config: self.userConfig) {
                        self.readWordFromCloud(wordId: wordId) { (word) in
                            completion(word, AEWord(wordId: wordId))
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
        //      for type 1 (void forgetting words)
        //    ○ D: 1/16 (0)
        //    ○ C: 2/16 (1-2)
        //    ○ E: 3/16 (3-5)
        //    ○ B: 5/16 (6-10)
        //    ○ A: 5/16 (11-15)
        //      for type 2 (repeat forgetting words)
        //    ○ A: 1/16 (0)
        //    ○ C: 2/16 (1-2)
        //    ○ E: 3/16 (3-5)
        //    ○ B: 5/16 (6-10)
        //    ○ D: 5/16 (11-15)
        let ran = Int.random(in: 0..<16)
        var stateToPickNext: WordState
        switch ran {
        case 0: stateToPickNext = userConfig.aOrB == .a ? .d : .a
        case 1, 2: stateToPickNext = .c
        case 3, 4, 5: stateToPickNext = .e
        case 6, 7, 8, 9, 10: stateToPickNext = .b
        case 11, 12, 13, 14, 15: stateToPickNext = userConfig.aOrB == .a ? .a : .d
        default:
            fatalError("Got a random number outside of [0,15]")
        }
        
        // logic: the earliest from a given state, but it has to be dued.
        var result: AEWord? = nil
        let pred = anyAToEWord ? NSPredicate(value: true) : NSPredicate(format: "(state == %d) AND (dueAt < %@)", stateToPickNext.rawValue, Date() as NSDate)
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
    
    func readTouchedOrNotFromCloud(completion: @escaping (_ record: CKRecord) -> Void) {
        var result: CKRecord? = nil
        let pred = NSPredicate(value: true)
        let query = CKQuery(recordType: "TouchedOrNot", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            result = record
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            else if let result = result {
                completion(result)
            }
            else {
                // not error, but no result found, initialize it
                self.touchedOrNot = TouchedOrNot()
                self.writeTouchedOrNotToCloud { (record) in
                    completion(record)
                }
            }
        }
        publicDB.add(queryOp)

    }
    
    func writeTouchedOrNotToCloudIfNeeded(completion: @escaping () -> Void) {
        if nextAEWord.state == .f {
            writeTouchedOrNotToCloud() { _ in
                completion()
            }
        }
        else {
            completion()
        }
    }
    
    func writeTouchedOrNotToCloud(completion: @escaping (_ record: CKRecord) -> Void) {
        let record = CKRecord(recordType: "TouchedOrNot")
        record.setValue(self.touchedOrNot.touchedStr, forKey: "touched")
        record.setValue(self.touchedOrNot.untouchedStr, forKey: "untouched")
        publicDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if let rec = rec {
                completion(rec)
            }
            else {
                fatalError("neither record nor error has been return while saving touchedOrNot?!")
            }
        }
    }
    
    func readUserConfigFromCloud(_ userId: String, completion: @escaping (_ record: CKRecord?) -> Void) {
        let pred = NSPredicate(format: "userId = %@", userId)
        let query = CKQuery(recordType: "UserConfig", predicate: pred)
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
            else if let result = result {
                completion(result)
            }
            else {
                // not error, but no result found, initialize it
                self.userConfig = UserConfig(userId: userId)
                self.writeUserConfigToCloud { (record) in
                    completion(record)
                }
            }
        }
        publicDB.add(queryOp)
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
            else if let result = result {
                completion(result)
            }
            else if numOfDaysAgo == 0 {
                // for 0 day ago, not error, but no result found, initialize it
                self.latestStateCount = StateCount()
                self.writeLatestStateCountToCloud { (record) in
                    completion(record)
                }
            }
            else {
                completion(result)
            }
        }
        publicDB.add(queryOp)
    }
    
    func writeUserConfigToCloud(completion: @escaping (_ record: CKRecord) -> Void) {
        let record = CKRecord(recordType: "UserConfig")
        record.setValue(self.userConfig.userId, forKey: "userId")
        record.setValue(self.userConfig.aOrB.rawValue, forKey: "aOrB")
        record.setValue(self.userConfig.maxRange, forKey: "maxRange")
        publicDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if let rec = rec {
                completion(rec)
            }
            else {
                fatalError("neither record nor error has been return while saving user config?!")
            }
        }
    }
    
    func writeLatestStateCountToCloud(completion: @escaping (_ record: CKRecord) -> Void) {
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
            if let rec = rec {
                completion(rec)
            }
            else {
                fatalError("neither record nor error has been return while saving state count?!")
            }
        }
    }
    
    func writeLatestAEWordToCloud(newState: WordState, completion: @escaping () -> Void) {
        let record = nextAEWord.record ?? CKRecord(recordType: "AEWord")
        record.setValue(nextAEWord.newDueAt, forKey: "dueAt")
        record.setValue(nextAEWord.enqueueAt, forKey: "enqueueAt")
        record.setValue(newState.rawValue, forKey: "state")
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
        guard canResponseToTap else {
            return
        }
        
        if answered {
            canResponseToTap = false
            clearAnswers()
            transitionToNextWord()
        }
        else {
            canResponseToTap = false
            self.answered = true
            let tappedIndex = sender.view?.tag
            self.handleAnswer(hasCorrectAnswer: tappedIndex == self.correctAnswerIndex) { () in
                DispatchQueue.main.async {
                    self.transLabel1.alpha = 0
                    self.transLabel2.alpha = 0
                    self.transLabel3.alpha = 0
                    self.transLabel4.alpha = 0
                    
                    var correctLabel = UILabel()
                    switch self.correctAnswerIndex {
                    case 0: correctLabel = self.transLabel1
                    case 1: correctLabel = self.transLabel2
                    case 2: correctLabel = self.transLabel3
                    case 3: correctLabel = self.transLabel4
                    default: fatalError("correct answer index not 0 to 3?!")
                    }
                    correctLabel.text! += "\n\(self.nextWord.word)"
                    correctLabel.alpha = 1
                    
                    self.canResponseToTap = true
                }
            }
        }
    }
    
    func clearAnswers() {
        transLabel1.text = ""
        transLabel2.text = ""
        transLabel3.text = ""
        transLabel4.text = ""
        
        transLabel1.alpha = 0
        transLabel2.alpha = 0
        transLabel3.alpha = 0
        transLabel4.alpha = 0
        
        playAgainButton.isEnabled = false
    }
    
    func readUserIdFromCloud(complete: @escaping (_ instance: String) -> ()) {
        let container = CKContainer.default()
        container.fetchUserRecordID() { recordID, error in
            if let error = error {
                print(error.localizedDescription)
                fatalError("trying to fetch iCloud user id but got error?!")
            } else if let recordID = recordID {
                complete(recordID.recordName)
            }
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let newValueFloat = ceil(sender.value / maxRangeOneStep) * maxRangeOneStep
        let newValue = Int(newValueFloat) > StateCount.max ? StateCount.max : Int(newValueFloat)
        // update needed only when value is different
        if userConfig.maxRange != newValue {
            userConfig.maxRange = newValue
            writeUserConfigToCloud { (_) in
                DispatchQueue.main.async {
                    self.updateSlider()
                }
            }
        }
    }
    
    func updateSlider() {
        maxRangeSlider.value = Float(userConfig.maxRange ?? StateCount.max)
        maxRangeLabel.text = "词汇量 → \(userConfig.maxRange ?? StateCount.max)  "
    }
    
    @IBAction func playAgainTapped(_ sender: UIButton) {
        speak()
    }
}
