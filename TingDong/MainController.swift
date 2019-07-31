import UIKit
import CloudKit

class MainController: UIViewController {

    var publicDB: CKDatabase!
    var privateDB: CKDatabase!
    
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
        
        generatePublicData()
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
