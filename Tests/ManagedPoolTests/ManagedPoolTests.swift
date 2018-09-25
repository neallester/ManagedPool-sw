import XCTest
@testable import ManagedPool

final class ManagedPoolTests: XCTestCase {
    
    internal class TestObject {
        
        let id = UUID()
        var isActivated = false
        
    }
    
    func testBasicUsage() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError, create: newTestObject)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        let id1 = object1!.object.id
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!)
        pool.queue.sync {}
        XCTAssertNil (poolError)
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertEqual (id1.uuidString, status.cache[0].object.id.uuidString)
        }
        object1 = try pool.checkOut()
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        let id2 = object2!.object.id
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object2!)
        pool.queue.sync {}
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertEqual (id2.uuidString, status.cache[0].object.id.uuidString)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!)
        pool.queue.sync {}
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (id2.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1.uuidString, status.cache[1].object.id.uuidString)
        }
        XCTAssertNil (poolError)
        object2 = try pool.checkOut()
        XCTAssertEqual (id2.uuidString, object2!.object.id.uuidString)
        object1 = try pool.checkOut()
        XCTAssertNil (poolError)
        XCTAssertEqual (id1.uuidString, object1!.object.id.uuidString)
        var object3: PoolObject<TestObject>? = try pool.checkOut()
        let id3 = object3!.object.id
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        switch poolError! {
        case .poolEmpty:
            break
        default:
            XCTFail ("Expected .poolEmpty")
        }
        poolError = nil
        pool.checkIn(object3!)
        pool.checkIn(object2!)
        pool.checkIn(object1!)
        pool.queue.sync {}
        XCTAssertNil (poolError)
        object3 = nil
        object2 = nil
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id3.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2.uuidString, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id1.uuidString, status.cache[2].object.id.uuidString)
        }
        XCTAssertNil (poolError)
        var object = try pool.checkOut()
        XCTAssertEqual (id3.uuidString, object.object.id.uuidString)
        pool.checkIn(object)
        pool.queue.sync {}
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id2.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1.uuidString, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id3.uuidString, status.cache[2].object.id.uuidString)
        }
        object = try pool.checkOut()
        XCTAssertEqual (id2.uuidString, object.object.id.uuidString)
        pool.checkIn(object)
        pool.queue.sync {}
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id3.uuidString, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id2.uuidString, status.cache[2].object.id.uuidString)
        }
        object = try pool.checkOut()
        XCTAssertEqual (id1.uuidString, object.object.id.uuidString)
        pool.checkIn(object)
        pool.queue.sync {}
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id3.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2.uuidString, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id1.uuidString, status.cache[2].object.id.uuidString)
        }
        XCTAssertNil (poolError)
    }
    
    func  testTimeout() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = ManagedPool<TestObject>(capacity: 1, timeout: 0.00001, onError: onError, create: newTestObject)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        let id1 = object1!.object.id
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        switch poolError! {
        case .poolEmpty:
            break
        default:
            XCTFail ("Expected .poolEmpty")
        }
        poolError = nil
        let worker = DispatchQueue (label: "worker")
        let group = DispatchGroup()
        group.enter()
        worker.async {
            do {
                let _ = try pool.checkOut()
                XCTFail ("Expected Error")
            } catch {
                switch error {
                case ManagedPool<TestObject>.ManagedPoolError.timeout:
                    break
                default:
                    XCTFail ("Expected .timeout")
                }
                group.leave()
            }
        }
        switch group.wait(timeout: DispatchTime.now() + 10.0) {
        case .success:
            break
        default:
            XCTFail ("Expected success")
        }
        pool.checkIn(object1!)
        pool.queue.sync {}
        object1 = nil
        group.enter()
        worker.async {
            do {
                object1 = try pool.checkOut()
            } catch {
                XCTFail ("Expected success")
            }
            group.leave()
        }
        switch group.wait(timeout: DispatchTime.now() + 10.0) {
        case .success:
            break
        default:
            XCTFail ("Expected success")
        }
        XCTAssertEqual (id1.uuidString, object1!.object.id.uuidString)
    }
    
    func testCheckInNotOK () throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError, create: newTestObject)
        var ids = Set<UUID>()
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        ids.insert(object1!.object.id)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!, isOK: false)
        pool.queue.sync {}
        XCTAssertNil (poolError)
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        object1 = try pool.checkOut()
        ids.insert(object1!.object.id)
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        ids.insert(object2!.object.id)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object2!, isOK: false)
        pool.queue.sync {}
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!, isOK: false)
        pool.queue.sync {}
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        object2 = try pool.checkOut()
        XCTAssertFalse (ids.contains (object2!.object.id))
        ids.insert(object2!.object.id)
        object1 = try pool.checkOut()
        XCTAssertFalse (ids.contains (object1!.object.id))
        ids.insert(object1!.object.id)
        XCTAssertNil (poolError)
        var object3: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertFalse (ids.contains(object3!.object.id))
        ids.insert(object3!.object.id)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        switch poolError! {
        case .poolEmpty:
            break
        default:
            XCTFail ("Expected .poolEmpty")
        }
        poolError = nil
        pool.checkIn(object3!, isOK: false)
        pool.checkIn(object2!, isOK: false)
        pool.checkIn(object1!, isOK: false)
        pool.queue.sync {}
        XCTAssertNil (poolError)
        object3 = nil
        object2 = nil
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        var object = try pool.checkOut()
        
        pool.checkIn(object, isOK: false)
        pool.queue.sync {}
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        object = try pool.checkOut()
        XCTAssertFalse (ids.contains(object.object.id))
        pool.checkIn(object, isOK: false)
        pool.queue.sync {}
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
    }

    internal func testPrune() throws {
        
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = PruneGatedManagedPool<TestObject>(capacity: 3, idleTimeout: 0.000001, onError: onError, create: newTestObject)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        pool.checkIn(object1!)
        object1 = nil
        pool.checkIn(object2!)
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
    }
    
    internal func testPruneImmortal() throws {
        
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = PruneGatedManagedPool<TestObject>(capacity: 3, idleTimeout: 0.0, zeroIdleTimeoutPruneInterval: 0.000001, onError: onError, create: newTestObject)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        pool.checkIn(object1!)
        object1 = nil
        pool.checkIn(object2!)
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
    }

    internal func testPruneWithMinimumCacheSize() throws {
        
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = PruneGatedManagedPool<TestObject>(capacity: 6, minimumCached: 3, idleTimeout: 0.01, onError: onError, create: newTestObject)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
        }
        XCTAssertNil (poolError)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
        }
        pool.checkIn(object1!)
        object1 = nil
        pool.checkIn(object2!)
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (5, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (4, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        var id0 = ""
        var id1 = ""
        var id2 = ""
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        // Verify we are newing the cache as they expire
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        object1 = try pool.checkOut()
        XCTAssertEqual (id0, object1?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id2, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        object2 = try pool.checkOut()
        XCTAssertEqual (id0, object2?.object.id.uuidString)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id2, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        let object3: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object3?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id2, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        let object4: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object4?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (4, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (id2, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
        }
        let object5: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object5?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (5, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertTrue (id1 != status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
        }
        pool.checkIn(object1!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (4, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (object1?.object.id.uuidString, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
        }
        pool.checkIn(object2!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object3!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object4!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object5!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
    }

    internal func testPruneWithMinimumCacheSizeImmortal() throws {
        
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = PruneGatedManagedPool<TestObject>(capacity: 6, minimumCached: 3, idleTimeout: 0.0, zeroIdleTimeoutPruneInterval: 0.000001, onError: onError, create: newTestObject)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
        }
        XCTAssertNil (poolError)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        var object2: PoolObject<TestObject>? = try pool.checkOut()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
        }
        pool.checkIn(object1!)
        object1 = nil
        pool.checkIn(object2!)
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (5, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (4, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        var id0 = ""
        var id1 = ""
        var id2 = ""
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        // Verify we are newing the cache as they expire
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id0, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[2].object.id.uuidString)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id0, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[2].object.id.uuidString)
        }
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id0, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1, status.cache[1].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[2].object.id.uuidString)
        }
        object1 = try pool.checkOut()
        XCTAssertEqual (id0, object1?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        object2 = try pool.checkOut()
        XCTAssertEqual (id0, object2?.object.id.uuidString)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        let object3: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object3?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        let object4: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object4?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (4, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
        }
        let object5: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertEqual (id0, object5?.object.id.uuidString)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (5, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
        }
        pool.checkIn(object1!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (4, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (id0, status.cache[0].object.id.uuidString)
            id1 = status.cache[1].object.id.uuidString
        }
        pool.checkIn(object2!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (3, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id0, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1, status.cache[1].object.id.uuidString)
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object3!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (2, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object4!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
        pool.checkIn(object5!)
        XCTAssertNil (poolError)
        pool.releaseForPrune()
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)])) in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (3, status.cache.count)
            XCTAssertEqual (id1, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id2, status.cache[1].object.id.uuidString)
            id0 = status.cache[0].object.id.uuidString
            id1 = status.cache[1].object.id.uuidString
            id2 = status.cache[2].object.id.uuidString
        }
    }
    
    public func testActivateDeactivate() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let activate = { (object: TestObject) in
            object.isActivated = true
        }
        let deactivate = { (object: TestObject) in
            object.isActivated = false
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError, activate: activate, deactivate: deactivate, create: newTestObject)
        var object1: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertTrue (object1!.object.isActivated)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!)
        pool.queue.sync {}
        XCTAssertNil (poolError)
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertFalse (status.cache[0].object.isActivated)
        }
        object1 = try pool.checkOut()
        let object2: PoolObject<TestObject>? = try pool.checkOut()
        XCTAssertTrue (object1!.object.isActivated)
        XCTAssertTrue (object2!.object.isActivated)
        pool.checkIn(object1!)
        pool.checkIn(object2!)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertFalse (status.cache[0].object.isActivated)
            XCTAssertFalse (status.cache[1].object.isActivated)
        }
    }

    public func testInitError() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError) {
            throw PoolTestError.initError
        }
        do {
            let _ = try pool.checkOut()
            XCTFail ("Expected error")
        } catch {
            XCTAssertEqual ("creationError(ManagedPoolTests.ManagedPoolTests.PoolTestError.initError)", "\(error)")
        }
        XCTAssertEqual ("creationError(ManagedPoolTests.ManagedPoolTests.PoolTestError.initError)", "\(poolError!)")
    }

    public func testActivationError() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let activate = { (testObject: TestObject) in
            throw PoolTestError.activateError
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError, activate: activate, create: newTestObject)
        do {
            let _ = try pool.checkOut()
            XCTFail ("Expected error")
        } catch {
            XCTAssertEqual ("activationError(ManagedPoolTests.ManagedPoolTests.PoolTestError.activateError)", "\(error)")
        }
        XCTAssertEqual ("activationError(ManagedPoolTests.ManagedPoolTests.PoolTestError.activateError)", "\(poolError!)")
    }

    public func testDeactivationError() throws {
        var poolError: ManagedPool<TestObject>.ManagedPoolError? = nil
        let onError = { (error: ManagedPool<TestObject>.ManagedPoolError) in
            poolError = error
        }
        let deactivate = { (testObject: TestObject) in
            throw PoolTestError.deactivateError
        }
        let pool = ManagedPool<TestObject>(capacity: 3, onError: onError, deactivate: deactivate, create: newTestObject)
        var object = try pool.checkOut()
        XCTAssertNil (poolError)
        pool.checkIn(object, isOK: false)
        XCTAssertNil (poolError)
        object = try pool.checkOut()
        XCTAssertNil (poolError)
        pool.checkIn(object)
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (0, status.cache.count)
        }
        XCTAssertEqual ("deactivationError(ManagedPoolTests.ManagedPoolTests.PoolTestError.deactivateError)", "\(poolError!)")
    }

    func testCacheCapacity() {
        
        class NoCacheLoadPool<T: AnyObject> : ManagedPool<T> {
            
            override func prune() {}
            
        }
        
        var pool = NoCacheLoadPool<TestObject>(capacity: 10) {
            return TestObject()
        }
        XCTAssertEqual (10, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100) {
            return TestObject()
        }
        XCTAssertEqual (30, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 10, reservedCacheCapacity: 5) {
            return TestObject()
        }
        XCTAssertEqual (5, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 10, reservedCacheCapacity: 10) {
            return TestObject()
        }
        XCTAssertEqual (10, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 10, reservedCacheCapacity: 15) {
            return TestObject()
        }
        XCTAssertEqual (10, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 10, minimumCached: 10) {
            return TestObject()
        }
        XCTAssertEqual (10, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10) {
            return TestObject()
        }
        XCTAssertEqual (40, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 90)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 100) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 10, minimumCached: 10, reservedCacheCapacity: 5) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 10)

        pool = NoCacheLoadPool<TestObject>(capacity: 10, minimumCached: 10, reservedCacheCapacity: 15) {
            return TestObject()
        }
        XCTAssertEqual (10, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10, reservedCacheCapacity: 5) {
            return TestObject()
        }
        XCTAssertEqual (15, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10, reservedCacheCapacity: 25) {
            return TestObject()
        }
        XCTAssertEqual (35, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10, reservedCacheCapacity: 50) {
            return TestObject()
        }
        XCTAssertEqual (60, pool.cacheCapacity())
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10, reservedCacheCapacity: 100) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 10, reservedCacheCapacity: 150) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60, reservedCacheCapacity: 5) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 65)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60, reservedCacheCapacity: 25) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 85)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60, reservedCacheCapacity: 50) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60, reservedCacheCapacity: 100) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 60, reservedCacheCapacity: 150) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 100, reservedCacheCapacity: 5) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
        pool = NoCacheLoadPool<TestObject>(capacity: 100, minimumCached: 100, reservedCacheCapacity: 100) {
            return TestObject()
        }
        XCTAssertTrue (pool.cacheCapacity() >= 100)
    }
    
    func testStatusReport() throws {
        let pool = ManagedPool<TestObject>(capacity: 3, create: newTestObject)
        var status = pool.status()
        XCTAssertEqual (0, status.checkedOut)
        XCTAssertEqual (0, status.cached)
        XCTAssertNil (status.firstExpires)
        XCTAssertNil (status.lastExpires)
        let o1 = try pool.checkOut()
        status = pool.status()
        XCTAssertEqual (1, status.checkedOut)
        XCTAssertEqual (0, status.cached)
        XCTAssertNil (status.firstExpires)
        XCTAssertNil (status.lastExpires)
        let o2 = try pool.checkOut()
        status = pool.status()
        XCTAssertEqual (2, status.checkedOut)
        XCTAssertEqual (0, status.cached)
        XCTAssertNil (status.firstExpires)
        XCTAssertNil (status.lastExpires)
        status = pool.status()
        let now = Date().timeIntervalSince1970
        pool.checkIn(o1)
        status = pool.status()
        XCTAssertEqual (1, status.checkedOut)
        XCTAssertEqual (1, status.cached)
        XCTAssertEqual (status.firstExpires!.timeIntervalSince1970, status.lastExpires!.timeIntervalSince1970)
        XCTAssertTrue (status.firstExpires!.timeIntervalSince1970 > now)
        pool.checkIn(o2)
        status = pool.status()
        XCTAssertEqual (0, status.checkedOut)
        XCTAssertEqual (2, status.cached)
        XCTAssertTrue (status.firstExpires!.timeIntervalSince1970 < status.lastExpires!.timeIntervalSince1970)
        XCTAssertTrue (status.lastExpires!.timeIntervalSince1970 > now)
    }
    
    class PruneGatedManagedPool<T: AnyObject> : ManagedPool<T> {
        
        // Create on main test thread
        public override init (capacity: Int, minimumCached: Int = 0, reservedCacheCapacity: Int = 30, idleTimeout: TimeInterval = 300.0, timeout: TimeInterval = 60.0, zeroIdleTimeoutPruneInterval: TimeInterval = 300.0, onError: ((ManagedPoolError) -> ())? = nil, activate: ((T) throws -> ())? = nil, deactivate: ((T) throws -> ())? = nil, create: @escaping () throws -> T) {
            reachedBeforeSemaphoreGroup.enter()
            beforeSemaphore.wait()
            super.init(capacity: capacity, minimumCached: minimumCached, reservedCacheCapacity: reservedCacheCapacity, idleTimeout: idleTimeout, timeout: timeout, zeroIdleTimeoutPruneInterval: zeroIdleTimeoutPruneInterval, onError: onError, activate: activate, deactivate: deactivate, create: create)
        }
        
        override func prune() {
            if isInitialPruneComplete {
                reachedBeforeSemaphoreGroup.leave()
                switch beforeSemaphore.wait (timeout: DispatchTime.now() + 10.0) {
                case .success:
                    break
                default:
                    XCTFail ("Expected success")
                }
                beforeSemaphore.signal()
                super.prune()
                pruneCompletedGroup.leave()
                switch afterSemaphore.wait (timeout: DispatchTime.now() + 10.0) {
                case .success:
                    break
                default:
                    XCTFail ("Expected success")
                }
                afterSemaphore.signal()
            } else {
                isInitialPruneComplete = true
                super.prune()
            }
        }
        
        internal func releaseForPrune() {
            switch reachedBeforeSemaphoreGroup.wait(timeout: DispatchTime.now() + 10.0) {
            case .success:
                break
            default:
                XCTFail ("Expected success")
            }
            pruneCompletedGroup.enter()
            switch afterSemaphore.wait (timeout: DispatchTime.now() + 10.0) {
            case .success:
                break
            default:
                XCTFail ("Expected success")
            }
            beforeSemaphore.signal()
            switch pruneCompletedGroup.wait(timeout: DispatchTime.now() + 10.0) {
            case .success:
                break
            default:
                XCTFail ("Expected success")
            }
            reachedBeforeSemaphoreGroup.enter()
            switch beforeSemaphore.wait (timeout: DispatchTime.now() + 10.0) {
            case .success:
                break
            default:
                XCTFail ("Expected success")
            }
            afterSemaphore.signal()
        }
        
        var isInitialPruneComplete = false
        
        let beforeSemaphore = DispatchSemaphore (value: 1)
        let afterSemaphore = DispatchSemaphore (value: 1)
        let reachedBeforeSemaphoreGroup = DispatchGroup()
        let pruneCompletedGroup = DispatchGroup()
        
    }
    
    func testIsCached() throws {
        let pool = ManagedPool<TestObject>(capacity: 3, create: newTestObject)
        let object1 = try pool.checkOut()
        XCTAssertFalse (pool.isCached (object1.object))
        pool.checkIn (object1)
        XCTAssertTrue (pool.isCached (object1.object))
    }
    
    enum PoolTestError : Error {
        case initError
        case activateError
        case deactivateError
    }

    func newTestObject() -> TestObject {
        return TestObject()
    }

}
