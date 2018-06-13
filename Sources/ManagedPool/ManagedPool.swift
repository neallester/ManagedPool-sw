import Foundation

public struct PoolObject<T: AnyObject> {
    
    fileprivate init (_ object: T, pool: ManagedPool<T>) {
        self.object = object
        self.pool = pool
    }
    
    public let object: T
    fileprivate let pool: ManagedPool<T>

}

/**
    A thread safe pool of objects with internally managed expiration.
*/
public class ManagedPool<T: AnyObject> {
    
    public typealias StatusReport = (checkedOut: Int, cached: Int, firstExpires: Date?, lastExpires: Date?)
    
    public enum ManagedPoolError : Error {
        case timeout
        case wrongPool
        case poolEmpty
        case creationError (Error)
    }

/**
     - parameter capacity: The maximum number of objects which may be checked out at one time.
     - parameter minimumPopulation: The minimum number of objects to retain in the population (cached + checked out). **Default = 0**
     - parameter expiresAfter: Objects may be removed from the pool if they are not used within **expiresAfter** seconds of their checkIn. **Default = 300.0**
     - parameter timeout: The maximum number of seconds clients will wait for an object in the pool to become available. **Default = 60.0**
     - parameter onError: Closure to call when errors occur. The closure **must** be thread safe. **Default = nil**
     - parameter activate: Closure to call just before the pool provides a client with an object which has been checked out. **Default = nil**
     - parameter deactivate: Closure to call on an object which has been returned to the pool. The closure should return **true** if the object was succesfully deactivated. If the closure returns **false**, the object is not placed back in the pool's cache. **Default = nil**
     - parameter destroy: Closure to call on an object just before it will be removed from the pool. **Default = nil**
     - parameter create: Closure which creates new objects.
*/
    public init (capacity: Int, minimumPopulation: Int = 0, expiresAfter: TimeInterval = 300.0, timeout: TimeInterval = 60.0, onError: ((ManagedPoolError) -> ())? = nil, activate: ((T) throws -> ())? = nil, deactivate: ((T) -> Bool)? = nil, destroy: ((T) -> ())? = nil, create: @escaping () throws -> T) {
        precondition (capacity >= 1, "capacity >= 1")
        precondition (minimumPopulation >= 0, "minimumPopulation >= 0")
        precondition (minimumPopulation <= capacity, "minimumPopulation <= capacity")
        gate = DispatchSemaphore (value: capacity)
        self.expiresAfter = expiresAfter
        self.timeout = timeout
        self.onError = onError
        self.activate = activate
        self.deactivate = deactivate
        self.destroy = destroy
        self.create = create
        self.capacity = capacity
        self.minimumPopulation = minimumPopulation
        queue.async {
            var exceptionOccurred = false
            while !exceptionOccurred && self.population() < minimumPopulation {
                do {
                    exceptionOccurred = !self.addToCache()
                }
            }
        }
        self.prune()
    }
/**
     Obtain an object from the pool, waiting or creating a new object as needed.
     Client **must** use **checkIn()** to return object to the pool when finished with it.
     
     - returns: A PoolObject<T> containing the object.
     - throws: ManagedPoolError.timeout and any errors which may be thrown by the
               create or activate closures.
*/
    public func checkOut() throws -> PoolObject<T> {
        switch gate.wait(timeout: DispatchTime.now() + timeout) {
        case .success:
            var result: T? = nil
            try queue.sync {
                if cache.isEmpty {
                    do {
                        result = try create()
                    } catch {
                        if let onError = self.onError {
                            onError (.creationError(error))
                        }
                        throw ManagedPoolError.creationError(error)
                    }
                    
                } else {
                    result = cache.removeLast().object
                }
            }
            if let activate = self.activate {
                try activate (result!)
            }
            checkedOut = checkedOut + 1
            if checkedOut == capacity {
                if let onError = onError {
                    onError(.poolEmpty)
                }
            }
            return PoolObject (result!, pool: self)
        default:
            if let onError = self.onError {
                onError (.timeout)
            }
            throw ManagedPoolError.timeout
        }
    }
    
/**
     Return a previously checked out object to the pool. Clients **must** use this feature
     to return **all** checked out objects to the pool. **Do not** keep a reference to either the
     PoolObject or its object after checkIn.
     
     - parameter poolObject: The PoolObject<T> containing the object to be returned to the pool.
     - parameter isOK: Can poolObject.object remain in service? If true, poolObject.object is returned
                       to the cache where it may be checked out again. If false, poolObect.object
                       is discarded without calling deactivate. **Default = true**.
     
     - precondition: poolObject was initially checked out from this pool.
*/
    public func checkIn (_ poolObject: PoolObject<T>, isOK: Bool = true) {
        precondition (poolObject.pool === self, "poolObject is from the wrong pool")
        if poolObject.pool !== self, let onError = onError {
            onError (.wrongPool)
        }
        queue.sync {
            var needsReplacement = !isOK
            if isOK {
                if let deactivate = deactivate {
                    if deactivate (poolObject.object) {
                        self.addToCache(poolObject.object)
                    } else {
                        needsReplacement = true
                    }
                } else {
                    self.addToCache(poolObject.object)
                }
            }
            if needsReplacement {
                let _ = self.addToCache()
            }
            checkedOut = checkedOut - 1
            gate.signal()
        }
    }
/**
     Thread safe status report.
     
     - parameter closure: A closure which accepts a Tuple of type ManagedPool.StatusReport: (checkedOut: Int, cached: Int, firstExpires: Date?, lastExpires: Date?)
*/
    public func status (closure: (ManagedPool.StatusReport) -> ()) {
        queue.sync {
            closure ((checkedOut: self.checkedOut, cached: self.cache.count, firstExires: cache.first?.expires, lastExpires: cache.last?.expires) as! (checkedOut: Int, cached: Int, firstExpires: Date?, lastExpires: Date?))
        }
    }

    internal func status (closure: ((checkedOut: Int, cache: [(expires: Date, object: T)])) -> ()) {
        queue.sync {
            closure ((checkedOut: self.checkedOut, cache: cache))
        }
    }

    private func prune() {
        queue.sync {
            if
                !self.cache.isEmpty &&
                self.cache[0].expires.timeIntervalSince1970 < Date().timeIntervalSince1970 &&
                self.population() > self.minimumPopulation
            {
                let removed = self.cache.removeFirst()
                if let destroy = self.destroy {
                    destroy (removed.object)
                }
            } else if self.population() < self.minimumPopulation {
                let _ = addToCache()
            }
            if self.population() < self.minimumPopulation {
                queue.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: self.prune)
            } else if self.population() == self.minimumPopulation {
                queue.asyncAfter(deadline: DispatchTime.now() + expiresAfter, execute: self.prune)
            } else {
                let delay = self.cache.first!.expires.timeIntervalSince1970 - Date().timeIntervalSince1970 + 0.1
                if delay < 0 {
                    queue.async {
                        self.prune()
                    }
                } else {
                    queue.asyncAfter(deadline: DispatchTime.now() + delay, execute: self.prune)
                }
            }
        }
    }
    
    /// The maximum number of objects which may be checked out at one time.
    public let capacity: Int
    
    /// The minimum number of objects to retain in the population (cached + checked out).
    public let minimumPopulation: Int
    
    // Not thread safe; must be called while on queue
    private func addToCache(_ object: T) {
        self.cache.append((expires: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + self.expiresAfter), object: object))
    }
    
    // Not thread safe; must be called while on queue
    private func addToCache() -> Bool {
        do {
            try addToCache (create())
            return true
        } catch {
            if let onError = self.onError {
                onError (.creationError (error))
            }
            return false
        }
    }
    
    // Not thread safe; must be called whle on queue
    private func population() -> Int {
        return cache.count + checkedOut
    }

    
    private let activate: ((T) throws -> ())?
    private let deactivate: ((T) -> Bool)?
    private let destroy: ((T) -> ())?
    private let gate: DispatchSemaphore
    private let onError: ((ManagedPoolError) -> ())?
    private let expiresAfter: TimeInterval
    private let timeout: TimeInterval
    private let create: () throws -> T
    private let queue = DispatchQueue(label: "ManagedPool<\(T.self)>")
    private var cache: [(expires: Date, object: T)] = []
    private var checkedOut = 0

}
