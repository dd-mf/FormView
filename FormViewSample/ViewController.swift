//
//  ViewController.swift
//  FormViewSample
//
//  Created by J.Rodden on 8/12/20.
//

import UIKit
import FormView

class ViewController: UIViewController
{
    struct TestStruct: Assignable
    {
        var id: Int?
        var url: URL?
        var name = ""
        var email: String?
        var value: Decimal?
        var phone: String?
        var password: String?
        var droid: Droid = .R2D2
        var fooBarBaz: FooBarBaz = .foo
        var _fooBarBaz: FooBarBaz? = .foo
        var twitter: String?
        var something: String?
        var orOther: String?
        var andOneMore: String?
        
        enum Droid: String,
                    Codable,
                    Enumerable,
                    CaseIterable
        {
            case R2D2, C3PO, BB8, K2SO, L337, IG11
        }
        
        enum FooBarBaz: String,
                        Codable,
                        Enumerable,
                        CaseIterable
        {
            case foo, bar, baz
        }
        
        enum KeyPaths: KeyPathMapping
        {
            case id
            case url
            case name
            case email
            case value
            case phone
            case password
            case droid
            case fooBarBaz
            case _fooBarBaz
            case twitter
            case something
            case orOther
            case andOneMore

            var keyPath: AnyKeyPath
            {
                switch self
                {
                case .id:           return \TestStruct.id
                case .url:          return \TestStruct.url
                case .name:         return \TestStruct.name
                case .email:        return \TestStruct.email
                case .value:        return \TestStruct.value
                case .phone:        return \TestStruct.phone
                case .password:     return \TestStruct.password
                case .droid:        return \TestStruct.droid
                case .fooBarBaz:    return \TestStruct.fooBarBaz
                case ._fooBarBaz:   return \TestStruct._fooBarBaz
                case .twitter:      return \TestStruct.twitter
                case .something:    return \TestStruct.something
                case .orOther:      return \TestStruct.orOther
                case .andOneMore:   return \TestStruct.andOneMore
                }
            }
        }
        
        mutating func set<T>(_ key: String, to newValue: T?)
        {
            // fully support our enum value
            switch KeyPaths(stringValue: key)
            {
            case .droid:
                self[key] = newValue as? Droid
                
            case .fooBarBaz, ._fooBarBaz:
                self[key] = newValue as? FooBarBaz
                
            default: self[key] = newValue
            }
        }
    }
    
    private var form = FormView()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        title = "FormView"
        view.addSubview(form)

        form.addTextFields(for: TestStruct())

        navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .save,
                            target: (self, #selector(printValues)))

        form.translatesAutoresizingMaskIntoConstraints = false
        ["H:|-[form]-|", "V:|-[form]-|"].forEach { visualFormat in
            view.addConstraints(NSLayoutConstraint.constraints(
                                    withVisualFormat: visualFormat,
                                    metrics: nil, views: ["form": form]))
        }
    }

    @objc func printValues()
    {
        if let data = form.data
        {
            print("-- Data:\n\(data)")
        }
        
        if let values = form.values, !values.isEmpty
        {
            print("-- Raw Values:\n{"); defer { print("}")}
            values.forEach { print("\t\($0): \"\($1)\" <\(type(of: $1))>") }
        }
    }
}

