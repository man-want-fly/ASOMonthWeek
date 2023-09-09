//
//  ReusableObjectQueue.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import UIKit

public protocol ReusableObject: AnyObject {

    var reuseIdentifier: String { get set }

    func prepareForReuse()

    init()
}

public class ReusableObjectQueue {

    typealias T = ReusableObject

    private var reusableObjectsSets: [String: Set<ReusableObjectWrapper>] = [:]
    private var registeredClasses: [String: AnyClass] = [:]

    var count: Int {
        reusableObjectsSets.values.reduce(0) { res, items in
            var res = res
            res += items.count
            return res
        }
    }

    private var totalCreated = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(removeAllObjects),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func register(
        _ objectClass: AnyClass?,
        forObjectWithReuseIdentifier id: String
    ) {
        if let objectClass {
            let items = reusableObjectsSets[id]
            
            if let cls = objectClass as? T.Type, items == nil {
                reusableObjectsSets[id] = []
                registeredClasses[id] = cls
            }
        } else {
            registeredClasses.removeValue(forKey: id)
            reusableObjectsSets.removeValue(forKey: id)
        }
    }

    func enqueue(_ object: T) {
        let id = object.reuseIdentifier
        if var items = reusableObjectsSets[id] {
            items.insert(ReusableObjectWrapper(object))
            reusableObjectsSets[id] = items
        } else {
            reusableObjectsSets[id] = [ReusableObjectWrapper(object)]
        }
    }

    func dequeue(by reuseIdentifier: String) -> T? {
        if var items = reusableObjectsSets[reuseIdentifier],
            let wrapper = items.first
        {
            items.remove(wrapper)
            reusableObjectsSets[reuseIdentifier] = items

            wrapper.wrappedValue.prepareForReuse()
            return wrapper.wrappedValue
        } else {
            if let object = createReusableObject(by: reuseIdentifier) {
                totalCreated += 1
                return object
            }
        }

        return nil
    }

    private func createReusableObject(by reuseIdentifier: String) -> T? {
        guard let cls = registeredClasses[reuseIdentifier] as? T.Type else {
            return nil
        }
        return cls.init()
    }

    @objc private func removeAllObjects() {
        reusableObjectsSets.removeAll()
    }
}

private class ReusableObjectWrapper: Equatable, Hashable {

    let wrappedValue: ReusableObject

    init(_ wrappedValue: ReusableObject) {
        self.wrappedValue = wrappedValue
    }

    static func == (lhs: ReusableObjectWrapper, rhs: ReusableObjectWrapper) -> Bool {
        lhs.wrappedValue.reuseIdentifier == rhs.wrappedValue.reuseIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue.reuseIdentifier)
    }
}
