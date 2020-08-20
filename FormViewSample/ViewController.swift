//
//  ViewController.swift
//  FormViewSample
//
//  Created by J.Rodden on 8/12/20.
//

import UIKit
import FormView

extension UIBarButtonItem
{
    typealias Target = (Any, Selector)
    
    convenience init(image: UIImage?,
                     landscapeImagePhone landscapeImage: UIImage? = nil,
                     style: UIBarButtonItem.Style, target: Target?)
    {
        self.init(image: image, landscapeImagePhone: landscapeImage,
                  style: style, target: target?.0, action: target?.1)
    }

    convenience init(title: String?, style: UIBarButtonItem.Style, target: Target?)
    {
        self.init(title: title, style: style, target: target?.0, action: target?.1)
    }
    
    convenience init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem, target: Target?)
    {
        self.init(barButtonSystemItem: systemItem, target: target?.0, action: target?.1)
    }
}

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
        var fooBarBaz: FooBarBaz = .foo
        var twitter: String?
        var something: String?
        var orOther: String?
        var andOneMore: String?
        
        enum FooBarBaz: String,
                        Codable,
                        Enumerable,
                        CaseIterable
        {
            case foo, bar, baz
        }
        
        enum CodingKeys: KeyPathMapping
        {
            case id
            case url
            case name
            case email
            case value
            case phone
            case password
            case fooBarBaz
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
                case .fooBarBaz:    return \TestStruct.fooBarBaz
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
            if T.self == FooBarBaz.self ||
               !key.contains("fooBarBaz")
            {
                self[key] = newValue
            }
            else { set(key, to: newValue as? FooBarBaz) }
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

