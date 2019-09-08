import UIKit
import CloudKit

class MainController: UIViewController {
    
    var publicDB: CKDatabase!
    var privateDB: CKDatabase!
    var stateCount: StateCount!
    var wordJustReadFromCloud: Word!
    var touchedOrNot: TouchedOrNot!
    
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
        readLatestStateCountFromCloud { () in
            self.readTouchedOrNotFromCloud { () in
                completion()
            }
        }
    }
    
    func readNextWord(completion: @escaping () -> Void) {
        // if Cx4 > Sum(touched) and F is not empty: get from F.
        if (self.stateCount.c * 4 > self.stateCount.sum && (self.stateCount.sum < StateCount.max)) {
            self.readWordFromCloud(wordId: touchedOrNot.randomFWordId) { () in
                // todo: use the 'self.wordJustReadFromCloud'
            }
        }
        else {
            // todo: get from random(A to E). 
        }
    }
    
    func readWordFromCloud(wordId: Int, completion: @escaping () -> Void) {
        wordJustReadFromCloud = nil
        let pred = NSPredicate(format: "wordId == %d", wordId)
        let query = CKQuery(recordType: "Word", predicate: pred)
        let queryOp = CKQueryOperation(query: query)
        queryOp.resultsLimit = 1
        queryOp.recordFetchedBlock = { record in
            self.wordJustReadFromCloud = Word(record: record)
        }
        queryOp.queryCompletionBlock = { queryCursor, error in
            if let error = error {
                fatalError(error.localizedDescription)
            }
            completion()
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
            self.writeTouchedOrNot { () in
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasTouchedOrNotInitialized)
                self.privateDB.add(queryOp)
            }
        }
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
            self.writeLatestStateCount { () in
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
