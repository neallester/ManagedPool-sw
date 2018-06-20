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
    A tunable thread safe pool of objects with internally managed expiration.
*/
public class ManagedPool<T: AnyObject> {
    
    public typealias StatusReport = (checkedOut: Int, cached: Int, firstExpires: Date?, lastExpires: Date?)
    
    public enum ManagedPoolError : Error {
        case timeout
        case wrongPool
        case poolEmpty
        case creationError (Error)
        case activationError (Error)
        case deactivationError (Error)
    }

/**
     - parameter capacity: The maximum number of objects which may be checked out at one time.
     - parameter minimumCached: The minimum number of objects to retain in the cache. Actual cache count may drop below this
                 under high demand. **Default = 0**
     - parameter reservedCacheCapacity: The initial capacity reserved for the cache beyond **minimumCached**.
                 That is, initial cache reservedCapcity = (**minimumCached** + **reservedCacheCapcity**) or **capacity**,
                 whichever is less. **Default = 30**.
     - parameter idleTimeout: Objects will be removed from the pool if they are not used within **idleTimeout** seconds
                 of their checkIn. 0.0 means objects live forever. **Default = 300.0**
     - parameter timeout: The maximum number of seconds clients will wait for an object in the pool to become available.
                 **Default = 60.0**
     - parameter onError: Closure to call when errors occur. The closure **must** be thread safe. **Default = nil**
     - parameter activate: Closure to call just before the pool provides a client with an object which has been checked out.
                 **Default = nil**
     - parameter deactivate: Closure to call on an object which has been returned to the pool. The closure should return **true**
                 if the object was succesfully deactivated. If the closure returns **false**, the object is not placed back in the
                 pool's cache. **Default = nil**
     - parameter create: Closure which creates new objects. If **activate** and **deactivate** are provided, **create** should
                 return objects in the deactivated state.
*/
    public init (capacity: Int, minimumCached: Int = 0, reservedCacheCapacity: Int = 30, idleTimeout: TimeInterval = 300.0, timeout: TimeInterval = 60.0, onError: ((ManagedPoolError) -> ())? = nil, activate: ((T) throws -> ())? = nil, deactivate: ((T) throws -> ())? = nil, create: @escaping () throws -> T) {
        precondition (capacity > 0, "capacity > 0")
        precondition (minimumCached >= 0, "minimumCached >= 0")
        precondition (minimumCached <= capacity, "minimumCached <= capacity")
        precondition (reservedCacheCapacity >= 0, "reservedCacheCapacity >= 0")
        precondition (idleTimeout >= 0.0, "idleTimeout >= 0.0")
        precondition (timeout > 0.0, "timeout > 0.0")
        gate = DispatchSemaphore (value: capacity)
        self.idleTimeout = idleTimeout
        self.timeout = timeout
        self.onError = onError
        self.activate = activate
        self.deactivate = deactivate
        self.create = create
        self.capacity = capacity
        self.minimumCached = minimumCached
        if (minimumCached + reservedCacheCapacity > capacity) {
            cache.reserveCapacity(capacity)
        } else {
            cache.reserveCapacity(minimumCached + reservedCacheCapacity)
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
                    result = cache.removeFirst().object
                }
                if let activate = self.activate {
                    do {
                        try activate (result!)
                    } catch {
                        if let onError = self.onError {
                            onError (.activationError (error))
                            throw ManagedPool.ManagedPoolError.activationError (error)
                        }
                    }
                    
                }
                checkedOut = checkedOut + 1
                if checkedOut == capacity {
                    if let onError = onError {
                        onError(.poolEmpty)
                    }
                }
            }
            queue.async {
                if self.isCacheLow() {
                    let _ = self.addToCache()
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
        queue.async {
            var needsReplacement = !isOK
            if isOK {
                if let deactivate = self.deactivate {
                    do {
                       try deactivate (poolObject.object)
                        self.addToCache(poolObject.object)
                    } catch {
                        if let onError = self.onError {
                            onError (.deactivationError (error))
                        }
                        needsReplacement = true
                    }
                } else {
                    self.addToCache(poolObject.object)
                }
            }
            if needsReplacement {
                if self.isCacheLow() {
                    let _ = self.addToCache()
                }
            }
            self.checkedOut = self.checkedOut - 1
            self.gate.signal()
        }
    }
/**
     Thread safe status report.
     
     - parameter closure: A closure which accepts a Tuple of type ManagedPool.StatusReport: (checkedOut: Int, cached: Int, firstExpires: Date?, lastExpires: Date?)
*/
    public func status () -> ManagedPool.StatusReport {
        var result: ManagedPool.StatusReport? = nil
        queue.sync {
            result = (checkedOut: self.checkedOut, cached: self.cache.count, firstExpires: cache.first?.expires, lastExpires: cache.last?.expires)
        }
        return result!
    }
    
/**
     Prepare for deinitialization. Failure to call this function before dereferencing a pool may cause a memory
     leak due to the strong reference held by the dispatch job used to periodically prune the pool of stale objects in
     the cache. Note that the invalidated pool will remain in memory until the existing dispatch job runs.
*/
    public func invalidate() {
        queue.sync {
            wasInvalidated = true
            cache = []
        }
    }

    internal func status (closure: ((checkedOut: Int, cache: [(expires: Date, object: T)])) -> ()) {
        queue.sync {
            closure ((checkedOut: self.checkedOut, cache: cache))
        }
    }
    
    // Check for and remove stale objects from the cache.
    internal func prune() {
        queue.sync {
            if !wasInvalidated {
                if
                    !self.cache.isEmpty &&
                    self.idleTimeout > 0.0 &&
                    self.cache[0].expires.timeIntervalSince1970 < Date().timeIntervalSince1970
                {
                    let _ = self.cache.removeFirst()
                } else if
                    self.idleTimeout == 0.0 &&
                    self.cache.count > self.minimumCached
                {
                    let _ = self.cache.removeFirst()
                }
                if self.isCacheLow() {
                    let _ = self.addToCache()
                }
                if self.isCacheLow() {
                    self.pruneQueue.async {
                        self.prune()
                    }
                } else if self.idleTimeout == 0.0 {
                    self.pruneQueue.asyncAfter (deadline: DispatchTime.now() + self.zeroIdleTimeoutPruneDelay()) {
                        self.prune()
                    }
                } else if self.cache.isEmpty {
                    self.pruneQueue.asyncAfter (deadline: DispatchTime.now() + self.idleTimeout) {
                        self.prune()
                    }
                } else {
                    let delay = self.cache.first!.expires.timeIntervalSince1970 - Date().timeIntervalSince1970 + 0.1
                    if delay <= 0.0 {
                        self.pruneQueue.async {
                            self.prune()
                        }
                    } else {
                        self.pruneQueue.asyncAfter (deadline: DispatchTime.now() + delay) {
                            self.prune()
                        }
                    }
                }
            }
        }
    }
    
    /// The maximum number of objects which may be checked out at one time.
    public let capacity: Int
    
    /// The minimum number of objects to retain in the population (cached + checked out).
    public let minimumCached: Int
    
    // Not thread safe; must be called while on queue
    private func addToCache(_ object: T) {
        self.cache.append((expires: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + self.idleTimeout), object: object))
    }
    
    // Not Thread safe; must be called while on queue
    private func isCacheLow() -> Bool {
        return (cache.count < minimumCached) && ((cache.count + checkedOut) < capacity)
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
    
    /// Prune delay in seconds to use if idleTimeout == 0.0 (descendants may override)
    public func zeroIdleTimeoutPruneDelay() -> TimeInterval {
        return 300.0
    }
    
    internal func cacheCapacity() -> Int {
        var result = 0
        queue.sync {
            result = cache.capacity
        }
        return result
    }

    private var cache: [(expires: Date, object: T)] = []
    private var checkedOut = 0
    private var wasInvalidated = false
    
    internal let queue = DispatchQueue(label: "ManagedPool<\(T.self)>")
    // prune must be executed on its own queue in order for PruneGatedManagedPool (which controls execution of prune) to work
    internal let pruneQueue = DispatchQueue(label: "ManagedPool<\(T.self)>.prune")
    private let activate: ((T) throws -> ())?
    private let deactivate: ((T) throws -> ())?
    private let gate: DispatchSemaphore
    private let onError: ((ManagedPoolError) -> ())?
    private let idleTimeout: TimeInterval
    private let timeout: TimeInterval
    private let create: () throws -> T

}
