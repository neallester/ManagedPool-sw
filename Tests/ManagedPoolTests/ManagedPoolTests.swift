import XCTest
@testable import ManagedPool

@available(OSX 10.12, *)
final class ManagedPoolTests: XCTestCase {
    
    internal class TestObject {
        
        let id = UUID()
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
    }

    internal func testPrune() throws {
        
        class PruneGatedManagedPool<T: AnyObject> : ManagedPool<T> {
            
            // Create on main test thread
            public override init (capacity: Int, minimumCached: Int = 0, reservedCacheCapacity: Int = 30, idleTimeout: TimeInterval = 300.0, timeout: TimeInterval = 60.0, onError: ((ManagedPoolError) -> ())? = nil, activate: ((T) throws -> ())? = nil, deactivate: ((T) throws -> ())? = nil, create: @escaping () throws -> T) {
                reachedBeforeSemaphoreGroup.enter()
                beforeSemaphore.wait()
                super.init(capacity: capacity, minimumCached: minimumCached, reservedCacheCapacity: reservedCacheCapacity, idleTimeout: idleTimeout, timeout: timeout, onError: onError, activate: activate, deactivate: deactivate, create: create)
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

    func newTestObject() -> TestObject {
        return TestObject()
    }

}
