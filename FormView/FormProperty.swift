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
            case date(DatePicker.Config, DateFormatter)
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
            else if type(of: value, is: Date.self)
            {
                let delegate = formView?.formViewDelegate
                let format = delegate?.dateFormat(
                    for: property.label) ?? DatePicker.Format()
                let config = delegate?.dateConfiguration(
                    for: property.label) ?? DatePicker.Config()

                kind = .date(config, DateFormatter(format))
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
                case .date: return self.date(from: rawValue)
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
                
        var keyboardType: UIKeyboardType
        {
            switch kind
            {
            case .int: return .numberPad
            case .decimal: return .decimalPad
            case .date, .enum: return .default
            case .string(let keyboardType): return keyboardType
            }
        }
    }
}

// MARK: -

extension FormView.Property
{
    internal func date(from string: String?) -> Date?
    {
        guard case let .date(_, formatter) = kind else { return nil }
        return formatter.date(from: string ?? "") ?? Date()
    }
    
    internal func string(from date: Date) -> String?
    {
        guard case let .date(_, formatter) = kind else { return nil }
        return formatter.string(from: date)
    }
}

// MARK: -

internal extension _Assignable
{
    typealias Property = FormView.Property
    
    mutating func set(_ property: Property, to value: Any?) -> Self
    {
        func set<T>(as type: T.Type) -> Self
        {
            self.set(property.label, to: value as? T); return self
        }
        
        switch property.kind
        {
        case .string(.URL): return set(as: URL.self)
            
        case .int:          return set(as: Int.self)
        case .enum:         return set(as: Any.self)
        case .date:         return set(as: Date.self)
        case .decimal:      return set(as: Decimal.self)
        
        default:            return set(as: String.self)
        }
    }
}
