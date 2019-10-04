import UIKit
import CloudKit

class WordListViewController: UIViewController {

    var publicDB: CKDatabase!
    var privateDB: CKDatabase!

    var wordId: Int = 0
    
    @IBOutlet weak var countDownLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let container = CKContainer.default()
        publicDB = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase
    }
    
    @IBAction func DeleteAllTapped(_ sender: UIButton) {
        removeAllWords()
    }
    
    @IBAction func insertAllTapped(_ sender: UIButton) {
        generatePublicData()
    }
    
    func generatePublicData() -> Void {
        // load json file into array obj
        if let path = Bundle.main.path(forResource: "words", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                do {
                    let words = try JSONDecoder().decode([WordDto].self, from: data)
                    var publicWordListInsertCurrentWordId = UserDefaults.standard.integer(forKey: "publicWordListInsertCurrentWordId")
                    if publicWordListInsertCurrentWordId == 0 { publicWordListInsertCurrentWordId = 1 }
                    addNewWordToPublicUntilDone(wordId: publicWordListInsertCurrentWordId, words: words)
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
        
        publicDB.save(record) { (record, error) -> Void in
            if let e = error {
                print(e)
            }
            else {
                DispatchQueue.main.async {
                    self.countDownLabel.text = "\(wordId) / \(words.count)"
                    let nextWordId = wordId + 1
                    if nextWordId <= words.count {
                        UserDefaults.standard.set(nextWordId, forKey: "publicWordListInsertCurrentWordId")
                        self.addNewWordToPublicUntilDone(wordId: nextWordId, words: words)
                    }
                    else {
                        self.countDownLabel.text = "\(wordId) / \(words.count) and all done!"
                    }
                }
            }
        }
    }
    
    func removeAllWords() {
        let query = CKQuery(recordType: "Word", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        let myDelete = iCloudDelete(cloudDB: publicDB, countDownLabel: countDownLabel)
        myDelete.delete(query: query) { () in
            DispatchQueue.main.async {
                self.countDownLabel.text = "all done!"
                UserDefaults.standard.set(0, forKey: "publicWordListInsertCurrentWordId")
            }
            print("all done!")
        }
    }
}

struct WordDto: Codable {
    var word: String
    var translation: String

    private enum CodingKeys: String, CodingKey {
        case word = "w"
        case translation = "t"
    }
}

class iCloudDelete {

    private let cloudDB: CKDatabase
    private var recordIDsToDelete = [CKRecord.ID]()
    private var onAllQueriesCompleted : (()->())?
    private var label: UILabel

    public var resultsLimit = 100 // default is 100

    init(cloudDB: CKDatabase, countDownLabel: UILabel){
        self.cloudDB = cloudDB
        self.label = countDownLabel
   }

   func delete(query: CKQuery, onComplete: @escaping ()->Void) {
       onAllQueriesCompleted = onComplete
       add(queryOperation: CKQueryOperation(query: query))
   }

   private func add(queryOperation: CKQueryOperation) {
       queryOperation.resultsLimit = resultsLimit
       queryOperation.queryCompletionBlock = queryDeleteCompletionBlock
       queryOperation.recordFetchedBlock = recordFetched
       cloudDB.add(queryOperation)
   }

    private func queryDeleteCompletionBlock(cursor: CKQueryOperation.Cursor?, error: Error?) {
        print("-----------------------")
        DispatchQueue.main.async {
            self.label.text = self.recordIDsToDelete.last?.recordName
        }
        delete(ids: recordIDsToDelete) {
            self.recordIDsToDelete.removeAll()

            if let cursor = cursor {
                self.add(queryOperation: CKQueryOperation(cursor: cursor))
            } else {
                self.onAllQueriesCompleted?()
            }
        }
   }

   private func recordFetched(record: CKRecord) {
       print("RECORD fetched: \(record.recordID.recordName)")
       recordIDsToDelete.append(record.recordID)
   }

    private func delete(ids: [CKRecord.ID], onComplete: @escaping ()->Void) {
       let delete = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
       delete.completionBlock = {
           onComplete()
       }
       cloudDB.add(delete)
   }
}
