import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!
    var stateCount: StateCount!

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
        
        readLatestStateCount { () in
            // todo:
        }
    }
    
    func pickNextWord(completion: @escaping (CKRecord?, Error?) -> Void) {
    }
    
    func stateGroupToPick(completion: @escaping (WordState) -> Void) {
        
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
        queryOp.queryCompletionBlock = {
            queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            if self.stateCount == nil {
                self.stateCount = StateCount()
            }
            completion()
        }
        privateDB.add(queryOp)
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
