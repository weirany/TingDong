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
    
    func generatePublicData() -> Void {
        // load json file into array obj
        if let path = Bundle.main.path(forResource: "words_mini", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                do {
                    let words = try JSONDecoder().decode([WordDto].self, from: data)
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
        
        publicDB.save(record) { (record, error) -> Void in
            if let e = error {
                print(e)
            }
            else {
                DispatchQueue.main.async {
                    self.countDownLabel.text = "\(wordId) / \(words.count)"
                    let nextWordId = wordId + 1
                    if nextWordId <= words.count {
                        self.addNewWordToPublicUntilDone(wordId: nextWordId, words: words)
                    }
                }
            }
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
