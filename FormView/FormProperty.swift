//
//  FormProperty.swift
//  FormView
//
//  Created by J.Rodden on 9/2/20.
//

import UIKit

extension FormView
{
    internal struct Property
    {
        let kind: Kind
        let label: String
        let isOptional: Bool
        
        enum Kind
        {
            case int, decimal
            case string(UIKeyboardType)
            case `enum`(Enumerable.Type)
        }
        
        init?(_ property: Mirror.Child, _ formView: FormView? = nil)
        {
            label = property.label ?? ""
            let value = property.value
            isOptional = Mirror(reflecting: value).isA(.optional)
            
            if let enumerable =
                unwrap(value) as? Enumerable
            {
                kind = .enum(type(of: enumerable))
            }
            else if type(of: value, is: String.self)
            {
                var keyboardType: UIKeyboardType = .default
                for (keyword, keyboard): (String, UIKeyboardType) in
                    [("email", .emailAddress), ("url", .URL),
                     ("phone", .phonePad), ("twitter", .twitter)]
                {
                    if property.label?
                        .contains(keyword) == true
                    {
                        keyboardType = keyboard; break
                    }
                }
                
                kind = .string(keyboardType)
            }
            else if type(of: value, is: Int.self) { kind = .int }
            else if type(of: value, is: Decimal.self) { kind = .decimal }
            else if type(of: value, is: URL.self) { kind = .string(.URL) }

            else { return nil }
        }
        
        var convert: (String?) -> (Any?)
        {
            return {
                let rawValue = $0 ?? ""
                guard !rawValue.isEmpty || !isOptional else { return nil }
                
                switch kind
                {
                case .int: return Int(rawValue)
                case .decimal: return Decimal(string: rawValue)
                case .string(.URL): return URL(string: rawValue)
                    
                case .enum(let type): return type.init(rawValue: rawValue)
                    
                case .string(let keyboard):
                    guard keyboard == .phonePad else { return rawValue }
                    let nonDigits = CharacterSet.decimalDigits.inverted
                    return rawValue.components(separatedBy: nonDigits).joined()
                }
            }
        }
        
        func setter(for key: String, on target: inout _Assignable?) -> (Any) -> (_Assignable?)
        {
            guard var target = target else { return { _ in nil} }
            
            func set<T>(as type: T.Type) -> (Any) -> (_Assignable?)
            {
                return { target.set(key, to: $0 as? T); return target }
            }
            
            switch kind
            {
            case .enum(_):      return set(as: Any.self)
            case .string(.URL): return set(as: URL.self)
                
            case .int:          return set(as: Int.self)
            case .decimal:      return set(as: Decimal.self)
            
            default:            return set(as: String.self)
            }
        }
        
        var keyboardType: UIKeyboardType
        {
            switch kind
            {
            case .int: return .numberPad
            case .enum(_): return .default
            case .decimal: return .decimalPad
            case .string(let keyboardType): return keyboardType
            }
        }
    }
}
