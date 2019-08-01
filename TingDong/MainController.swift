import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!
    var stateCount: StateCount!
    var nextWord: Word!
    var touchedOrNot: TouchedOrNot!
    
    // for fill public word list only
    var wordId: Int = 0
    var words: [WordDto] = []
    
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
        
        initAllLocalVarsFromCloud { () in
            // todo: start logic
        }
    }
    
    func initAllLocalVarsFromCloud(completion: @escaping () -> Void) {
        readLatestStateCount { () in
            self.readTouchedOrNot { () in
                completion()
            }
        }
    }
    
    func readNextWord(completion: @escaping () -> Void) {
        // if Cx4 > Sum(touched) and F is not empty: get from F.
        if (self.stateCount.c * 4 > self.stateCount.sum && (self.stateCount.sum < StateCount.max)) {
            
        }
        else {
        }
    }
    
    func readTouchedOrNot(completion: @escaping () -> Void) {
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
                self.touchedOrNot = TouchedOrNot()
                self.writeTouchedOrNot { () in }
            }
            completion()
        }
        privateDB.add(queryOp)
    }
    
    func writeTouchedOrNot(completion: @escaping () -> Void) {
        let record = CKRecord(recordType: "TouchedOrNot")
        record.setValue(self.touchedOrNot.touched, forKey: "touched")
        record.setValue(self.touchedOrNot.untouched, forKey: "untouched")
        privateDB.save(record) { (rec, error) in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
        }
    }

    func readLatestStateCount(completion: @escaping () -> Void) {
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
                self.stateCount = StateCount()
                self.writeLatestStateCount { () in }
            }
            completion()
        }
        privateDB.add(queryOp)
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
    
    func addStateCount(completion: @escaping (CKRecord?, Error?) -> Void) {
//        let record = CKRecord(recordType: "StateCount")
//        record["]
    }

    func generatePublicData() -> Void {
        // load json file into array obj
        if let path = Bundle.main.path(forResource: "words", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                do {
                    words = try JSONDecoder().decode([WordDto].self, from: data)
                    addNewWordToPublicUntilDone(wordId: 1, words: words)
                } catch {
                    print(error)
                }
            } catch {
                print(error)
            }
        }
    }
    
    func addNewWordToPublicUntilDone(wordId: Int, words: [WordDto]) -> Void {
        let word = words[wordId - 1]
        let record = CKRecord(recordType: "Word")
        record["wordId"] = wordId
        record["word"] = word.word
        record["translation"] = word.translation
        print(wordId)
        publicDB.save(record) { (record, error) -> Void in
            if let e = error {
                print(e)
            }
            else {
                let nextWordId = wordId + 1
                if nextWordId <= words.count {
                    self.addNewWordToPublicUntilDone(wordId: nextWordId, words: words)
                }
            }
        }
    }
}

struct WordDto: Codable {
    let word: String
    let translation: String
    
    private enum CodingKeys: String, CodingKey {
        case word = "w"
        case translation = "t"
    }
}

enum WordState {
    case a, b, c, d, e
}
