import XCTest
@testable import ManagedPool

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
        object2 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (1, status.checkedOut)
            XCTAssertEqual (1, status.cache.count)
            XCTAssertEqual (id2.uuidString, status.cache[0].object.id.uuidString)
        }
        XCTAssertNil (poolError)
        pool.checkIn(object1!)
        object1 = nil
        pool.status() { (status: (checkedOut: Int, cache: [(expires: Date, object: TestObject)]))  in
            XCTAssertEqual (0, status.checkedOut)
            XCTAssertEqual (2, status.cache.count)
            XCTAssertEqual (id2.uuidString, status.cache[0].object.id.uuidString)
            XCTAssertEqual (id1.uuidString, status.cache[1].object.id.uuidString)
        }
        XCTAssertNil (poolError)
        object1 = try pool.checkOut()
        XCTAssertEqual (id1.uuidString, object1!.object.id.uuidString)
        object2 = try pool.checkOut()
        XCTAssertNil (poolError)
        XCTAssertEqual (id2.uuidString, object2!.object.id.uuidString)
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

    func newTestObject() -> TestObject {
        return TestObject()
    }

}
