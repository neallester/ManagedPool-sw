# ManagedPool-sw
A tunable thread safe pool of objects with internally managed expiration.

## Adding To Project

````swift
    dependencies: [
        .package(url: "https://github.com/neallester/ManagedPool-sw.git", .branch("master")),
    ],
    targets: [
        .target(
            dependencies: ["ManagedPool"]),
    ]
````

## Usage
To create a pool with the default parameters:

````swift

class MyClass {
    func doSomething() {}
}

let pool = ManagedPool<MyClass>(capacity: 10) {
    return MyClass()
}

{
    let m = try pool.checkout()
    m.object.doSomething()
    pool.checkIn (m)
}

// Invalidate the pool before its variable goes out of scope (or is set to nil) or the
// memory used by the pool will never be collected

pool.invalidate()

````
See the [ManagedPool.init()](https://github.com/neallester/ManagedPool-sw/blob/55fc64bcd617f5ee3bf0bdc0a688c40cb6503acb/Sources/ManagedPool/ManagedPool.swift#L54) for all of the parameters which may be used to tune the behavior of the pool.

