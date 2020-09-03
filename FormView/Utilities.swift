//
//  Utilities.swift
//  FormView
//
//  Created by J.Rodden on 8/10/20.
//

import UIKit

extension UIView
{
    var root: UIView?
    {
        guard let superview =
                superview else { return nil }
        
        let root = superview.root
        return root == nil ? superview : root
    }
    
    func removeAllSubviews()
    {
        subviews.forEach { $0.removeFromSuperview() }
    }
}

func execute<T>(_ action: () -> T) -> T { return action() }

func type<T: Any>(of thing: Any, is: T.Type) -> Bool
{
    type(of: thing) == T.self || type(of: thing) == Optional<T>.self
}

func unwrap(_ any: Any) -> Any?
{
    // how-to-unwrap-an-optional-value-from-any-type
    // https://stackoverflow.com/questions/27989094
    let mirror = Mirror(reflecting: any)
    guard mirror.isA(.optional) else { return any }
    guard let (_, value) = mirror.children.first else { return nil }
    
    return unwrap(value)
}

// MARK: -

// example usages of ifLet:
//
//     ifLet(bar) { foo = $0 }
//
// is equivalent to:
//
//     if let bar = bar { foo = bar }
//
// where the latter can yield high cyclomatic complexity, and
//
//     let foo = ifLet(bar) { return something(from: $0) }
//
// is equivalent to:
//
//     let foo = {
//         guard let bar = $0
//         else { return nil }
//         return something(from: bar)
//     }()
//
//     let foo: xxx
//     if let bar = bar {
//         foo = something(from: bar)
//     } else {
//         foo = nil
//     }
//
// where the code obfuscates the real intent of assigning something(from: bar)
// to foo. IfLet provides similar simplicity to that of the trinary operator:
//
//     let foo = (let bar = bar) ? something(from: bar) : nil
//
// but, of course, swift does not support that syntax because `let` by itself
// is a declaration that does not provide a Boolean result

/// syntactic sugar for if-let which eliminates cyclomatic complexity
/// and also provides for the ability to use ternary operator syntax with
/// an if-let as the boolean condition, which isn't otherwise possible
@discardableResult
func ifLet<T, Y>(_ optional: T?,
                 then: (T) -> Y) -> Y?
{
    if let temp = optional { return then(temp) } else { return nil }
}

/// syntactic sugar for if-let-else which eliminates cyclomatic complexity
/// and also provides for the ability to use ternary operator syntax with
/// an if-let as the boolean condition, which isn't otherwise possible
@discardableResult
func ifLet<T, Y>(_ optional: T?,
                 then: (T) -> Y,
                 else doThis: () -> Y?) -> Y?
{
    if let temp = optional { return then(temp) } else { return doThis() }
}

// MARK: -

extension CGRect
{
    func inset(by edge: UIEdgeInsets) -> CGRect
    {
        var this = self
        this.origin.y += edge.top
        this.origin.x += edge.left
        this.size.width -= edge.right - edge.left
        this.size.height -= edge.bottom - edge.top
        
        return this
    }
}

// MARK: -

extension String
{
    subscript(bounds: CountableClosedRange<Int>) -> String
    {
        let start = index(startIndex, offsetBy: min(count, bounds.lowerBound))
        let end = index(startIndex, offsetBy: min(count-1, bounds.upperBound))
        return String(self[start...end])
    }

    subscript(bounds: CountableRange<Int>) -> String
    {
        let start = index(startIndex, offsetBy: min(count, bounds.lowerBound))
        let end = index(startIndex, offsetBy: min(count, bounds.upperBound))
        return String(self[start..<end])
    }
}

// MARK: -

public protocol Assignable: _Assignable, Codable
{
    typealias CodingKeys = KeyPaths
    associatedtype KeyPaths: KeyPathMapping
}

public extension Assignable
{
    subscript<T>(_ key: String) -> T?
    {
        set { if let keyPath = KeyPaths(stringValue: key) { self[keyPath] = newValue } }
        get { if let keyPath = KeyPaths(stringValue: key) { return self[keyPath] } else { return nil } }
    }
    subscript<T>(_ key: KeyPaths) -> T?
    {
        get { self[keyPath: key.keyPath] as? T }
        set
        {
            let logging = false
            let newValue = unwrap(newValue as Any) as? T
            let log = { if logging { print("\(key) is now \(String(describing: newValue))") } }
            
            if let value = newValue,
               let kp = key.keyPath as? WritableKeyPath<Self, T> { self[keyPath: kp] = value; log() }
            else if let kp = key.keyPath as? WritableKeyPath<Self, T?> { self[keyPath: kp] = newValue; log() }
        }
    }
    
    /// Override this in your _Assignable_ struct/class in order to support (non-optional) enum values.
    /// Enum types must also be Enumerable, and be CaseIterable in order to gain automatic picker support.
    mutating func set<T>(_ key: String, to newValue: T?) { self[key] = newValue }

    internal static func keyPath(for key: String) -> AnyKeyPath? { KeyPaths.keyPath(for: key) }
}

public protocol _Assignable
{
    subscript<T>(_ key: String) -> T? { get set }
    mutating func set<T>(_ key: String, to newValue: T?)
}

// MARK: -

public protocol Enumerable
{
    init?(rawValue: String)
    var rawValue: String { get }
    static var allValues: [String] { get }
}

public extension Enumerable where Self: CaseIterable
{
    static var allValues: [String] { allCases.map { "\($0)"} }
}

// MARK: -

internal extension Mirror
{
    func isA(_ style: DisplayStyle) -> Bool { displayStyle == style }
}

// MARK: -

public protocol KeyPathMapping: CodingKey
{
    var keyPath: AnyKeyPath { get }
}

extension KeyPathMapping
{
    static func keyPath(for key: String) -> AnyKeyPath? { Self(stringValue: key)?.keyPath }
}

// MARK: -

public extension UIBarButtonItem
{
    typealias Target = (Any, Selector)

    class func fixedSpace(_ width: CGFloat) -> UIBarButtonItem
    {
        let result = UIBarButtonItem(barButtonSystemItem: .fixedSpace)
        result.width = width
        return result
    }

    class var flexibleSpace: UIBarButtonItem
    {
        if #available(iOS 14.0, *) { return flexibleSpace() }
        else { return UIBarButtonItem(barButtonSystemItem: .flexibleSpace) }
    }

    convenience init(title: String?, style: UIBarButtonItem.Style, target: Target? = nil)
    {
        self.init(title: title, style: style, target: target?.0, action: target?.1)
    }
    
    convenience init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem, target: Target? = nil)
    {
        self.init(barButtonSystemItem: systemItem, target: target?.0, action: target?.1)
    }
    
    convenience init(image: UIImage?,
                     landscapeImagePhone landscapeImage: UIImage? = nil,
                     style: UIBarButtonItem.Style, target: Target? = nil)
    {
        self.init(image: image, landscapeImagePhone: landscapeImage,
                  style: style, target: target?.0, action: target?.1)
    }
}

