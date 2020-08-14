//
//  FormView.swift
//  FormView
//
//  Created by J.Rodden on 8/10/20.
//

import UIKit

fileprivate extension CGFloat
{
    static let defaultSpacing = CGFloat(8)
}

// MARK: -

fileprivate enum SupportedType
{
    case int, decimal
    case string(UIKeyboardType)

    init?(_ property: Mirror.Child)
    {
        let value = property.value
        if type(of: value, is: Int.self) { self = .int; return }
        if type(of: value, is: Decimal.self) { self = .decimal; return }
        if type(of: value, is: URL.self) { self = .string(.URL); return }

        if type(of: value, is: String.self)
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
            
            self = .string(keyboardType); return
       }

        return nil
    }
    
    var convert: (String) -> (Any?)
    {
        switch self
        {
        case .int: return { Int($0) }
        case .decimal: return { Decimal(string: $0) }
        case .string(.URL): return { URL(string: $0) }
            
        case .string(.phonePad):
            let nonDigits = CharacterSet.decimalDigits.inverted
            return { $0.components(separatedBy: nonDigits).joined() }

        default: return { $0 }
        }
    }
    
    func assign(_ value: Any?, to target: inout _Assignable?, for key: String)
    {
        switch self
        {
        case .int:          target?[key] = value as? Int
        case .decimal:      target?[key] = value as? Decimal
        case .string(.URL): target?[key] = value as? URL
            
        default:            target?[key] = value as? String
        }
    }
    
    var keyboardType: UIKeyboardType
    {
        switch self
        {
        case .int: return .numberPad
        case .decimal: return .decimalPad
        case .string(let keyboardType): return keyboardType
        }
    }
}

// MARK: -

public class FormView: UIScrollView
{
    public var data: Any?
    {
        if isDirty
        {   // update
            _ = values
        }
        return _data
    }
    private var _data: Any?
    {
        didSet { isDirty = false }
    }
    private var isDirty = false

    private let stack: UIStackView = execute
    {
        let stack = UIStackView()
        
        stack.axis = .vertical
        stack.distribution = .fill
        stack.spacing = .defaultSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }
    
    public var values: [String: Any]?
    {
        guard let data = _data else { return nil }
        
        guard isDirty else
        {   // pull values from data
            var values = [String: Any]()
            Mirror(reflecting: data).children.forEach
            {
                if let label = $0.label,
                   let _ = SupportedType($0)
                {
                    values[label] = unwrap($0.value)
                }
            }
            
            return values
        }
        
        // pull rawValues from textFields
        var values = textFields.reduce([String: Any]())
        {
            guard let label = $1.placeholder,
                  let value = $1.text else { return $0 }
            
            return value.isEmpty ? $0 :
                $0.merging([label: value]) { (_, new) in new }
        }
        
        var updatedData = data as? _Assignable // copy on exit
        defer { if let newData = updatedData { _data = newData } }
        
        // convert rawValues into supportedType of data
        for property in Mirror(reflecting: data).children
        {
            guard let propertyName = property.label else { continue }
            
            guard let supportedType = SupportedType(property),
                  let rawValue = values[propertyName] as? String
            else { values.removeValue(forKey: propertyName); continue }
            
            values[propertyName] = supportedType.convert(rawValue)
            supportedType.assign(values[propertyName],
                                 to: &updatedData, for: propertyName)
        }
        
        return values
    }

    private var textFields = [UITextField]()
    private weak var currentTextField: UITextField?
    public weak var textFieldDelegate: UITextFieldDelegate?
    
    // MARK:
    
    deinit { NotificationCenter.default.removeObserver(self) }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        addSubview(stack)
 
        for notification in
            [UIResponder.keyboardWillShowNotification,
             UIResponder.keyboardWillHideNotification]
        {
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardChanged(_:)),
                name: notification, object: nil)
        }
        
        for edge: NSLayoutConstraint.Attribute in [.top, .left, .right, .bottom]
        {
            addConstraint(NSLayoutConstraint(
                            item: contentLayoutGuide, attribute: edge, relatedBy: .equal,
                            toItem: stack, attribute: edge, multiplier: 1, constant: 0))
            
            if edge != .bottom
            {
                addConstraint(NSLayoutConstraint(
                                item: frameLayoutGuide, attribute: edge, relatedBy: .equal,
                                toItem: contentLayoutGuide, attribute: edge, multiplier: 1, constant: 0))
            }
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: -

extension FormView
{
    private func createTextField(for property: Mirror.Child) -> UITextField?
    {
        guard let supportedType = SupportedType(property) else { return nil }

        let textField = UITextField()
        
        textField.returnKeyType = .next
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        
        if property.label?.lowercased()
            .contains("password") == true
        {
            textField.clearsOnInsertion = true
            textField.isSecureTextEntry = true
        }
        
        if let value = unwrap(property.value)
        {
            textField.text = "\(value)"
        }
        
        if let placeholder = property.label {
            textField.placeholder = "\(placeholder)"
        }

        textField.keyboardType = supportedType.keyboardType
        
        return textField
    }
    
    public enum LabelStyle
    {
        case none, `default`, centerAligned, leftAligned
        
        fileprivate var style: LabelStyle
        {
            (self == .default) ? .centerAligned : self
        }
    }
    
    public func addTextFields<T>(for template: T,
                                 editable: Bool = true,
                                 labels: LabelStyle = .default,
                                 customize: ((UIView)->())? = nil )
    {
        _data = template
        var labelWidth: CGFloat = 0

        defer { textFields.last?.returnKeyType = .done }
        
        let toolbar: UIToolbar = execute {
            let toolbar = UIToolbar()
            
            toolbar.items = [
                UIBarButtonItem(title: "\u{2191}", style: .plain,
                                target: self, action: #selector(advanceToPrevTextField)),
                UIBarButtonItem(title: "\u{2193}", style: .plain,
                                target: self, action: #selector(advanceToNextTextField)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Done", style: .plain,
                                target: delegate, action: #selector(stopEditing))
            ]

            toolbar.sizeToFit()
            return toolbar
        }

        for property in Mirror(reflecting: template).children
        {
            guard let textField = createTextField(for: property) else { continue }
            
            customize?(textField)
            textFields.append(textField)
            textField.tag = textFields.count

            textField.delegate = textField.delegate ?? self
            textField.isEnabled = textField.isEnabled && editable
            textField.inputAccessoryView = textField.inputAccessoryView ?? toolbar

            if labels.style != .none
            {
                let row = UIStackView()
                stack.addArrangedSubview(row)

                row.spacing = 8
                row.axis = .horizontal
                row.alignment = .center
                row.distribution = .fill
                row.contentMode = .scaleToFill

                let label = UILabel()
                label.text = property.label?.appending(":")

                customize?(label)
                row.addArrangedSubview(label)
                row.addArrangedSubview(textField)

                label.setContentHuggingPriority(.defaultHigh,
                                                for: .horizontal)
                
                if labels.style == .centerAligned
                {
                    label.textAlignment = .right
                    labelWidth = max(labelWidth,
                                     label.intrinsicContentSize.width)
                }
                
                addConstraints(NSLayoutConstraint.constraints(
                                withVisualFormat: "H:|[row]|",
                                metrics: nil, views: ["row": row]))
            } else {
                stack.addArrangedSubview(textField)
                addConstraints(NSLayoutConstraint.constraints(
                                withVisualFormat: "H:|[textField]|",
                                metrics: nil, views: ["textField": textField]))
            }
        }

        (labels.style == .centerAligned ? stack.subviews : []).forEach {
            guard let hStack = $0 as? UIStackView else { return }
            guard let label = hStack.subviews.first as? UILabel else { return }
            
            let visualFormat = String(format: "H:[label(%d)]",
                                      Int(ceil(labelWidth)))
            label.addConstraints(NSLayoutConstraint.constraints(
                                    withVisualFormat: visualFormat,
                                    metrics: nil, views: ["label": label]))
        }
    }
}

// MARK: -

extension FormView
{
    @objc public func stopEditing() { currentTextField?.resignFirstResponder() }
    
    /// add/remove extra padding to scrollView.contentSize so everything can be viewed
    @objc private func keyboardChanged(_ notification: Notification)
    {
        guard notification.name == UIResponder.keyboardWillShowNotification else
        {
            return UIView.animate(withDuration: 0.3)
            {
                self.contentInset = .zero
                self.scrollIndicatorInsets = .zero
            }
        }
        
        guard let frameInfo = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey],
              let keyboardFrame = (frameInfo as? NSValue)?.cgRectValue else { return }

        let contentInsets = UIEdgeInsets(top: 0, left: 0,
                                         bottom: keyboardFrame.height, right: 0)
        
        UIView.animate(withDuration: 0.3)
        {
            self.contentInset = contentInsets
            self.scrollIndicatorInsets = contentInsets
            if let tf = self.currentTextField { self.textFieldDidBeginEditing(tf) }
        }
    }
    
    @objc public func advanceToNextTextField() { advanceTextField(forward: true) }
    @objc public func advanceToPrevTextField() { advanceTextField(forward: false) }

    private func advanceTextField(forward: Bool)
    {
        guard let textField = currentTextField else { return }
        
        let nextIndex = textField.tag + (forward ? 1 : -1) - 1
        if nextIndex >= 0, nextIndex < textFields.count
        {
            textFields[nextIndex % textFields.count].becomeFirstResponder()
        }
    }
}

// MARK: - UITextFieldDelegate

extension FormView: UITextFieldDelegate
{
    // ensure textField is visible above virtual keyboard
    public func textFieldDidBeginEditing(_ textField: UITextField)
    {
        currentTextField = textField
        
        if let toolbarItems =
            (textField.inputAccessoryView as? UIToolbar)?.items
        {
            toolbarItems[0].isEnabled = textField != textFields.first
            toolbarItems[1].isEnabled = textField != textFields.last
        }

        if !bounds.inset(by: contentInset).contains(textField.frame)
        {
            scrollRectToVisible(textField.frame, animated: true)
        }
    }

    public func textFieldDidEndEditing(_: UITextField) { currentTextField = nil }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        switch textField.returnKeyType
        {
        case .done: stopEditing()
        default: advanceToNextTextField()
        }
        return false
    }
    
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool
    {
        var validCharacters: CharacterSet
        let oneTimeCharacter: CharacterSet
        let markDirty: (Bool) -> (Bool) = { self.isDirty = self.isDirty || $0; return $0 }
        
        func incomingStringOnlyContains(_ characters: [CharacterSet]) -> Bool
        {
            var validCharacters = CharacterSet()
            characters.forEach { validCharacters.formUnion($0) }
            return string.rangeOfCharacter(from: validCharacters.inverted) == nil
        }
        
        switch textField.keyboardType
        {
        case .emailAddress:
            validCharacters = .alphanumerics
            validCharacters.formUnion(
                CharacterSet(charactersIn: ".-"))
            oneTimeCharacter = CharacterSet(charactersIn: "@")
            
        case .decimalPad:
            validCharacters = .decimalDigits
            oneTimeCharacter = CharacterSet(
                charactersIn: Locale.current.decimalSeparator ?? ".")

        case .URL:
            return markDirty(incomingStringOnlyContains([.urlUserAllowed,
                                                         .urlHostAllowed,
                                                         .urlPathAllowed,
                                                         .urlQueryAllowed,
                                                         .urlFragmentAllowed,
                                                         .urlPasswordAllowed]))
            
        case .asciiCapable, .numbersAndPunctuation:
            return markDirty(incomingStringOnlyContains([.alphanumerics,
                                                         .punctuationCharacters]))
            
        case .asciiCapableNumberPad, .numberPad:
            return markDirty(incomingStringOnlyContains([.decimalDigits]))

        case .phonePad:
            guard incomingStringOnlyContains([.decimalDigits]) else { return markDirty(false) }
            if let originalText = textField.text, let range = Range(range, in: originalText)
            {
                let text = originalText.replacingCharacters(in: range, with: string)
                    .components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                
                switch text.count
                {                                                       
                case 0...4: textField.text = text
                case 5...7: textField.text = text[0...2] + "-" + text[3...6]
                    
                case 8...10: textField.text =
                    "(" + text[0...2] + ") " + text[3...5] + "-" + text[6...9]
                    
                default: break
                }
                
                _ = markDirty(originalText != textField.text)
            }
            
            return false
            
        default: return markDirty(true) // anything goes
        }
        
        // check for incoming validCharacters and oneTimeCharacter
        let numIncomingOneTimeCharacter = string
            .components(separatedBy: oneTimeCharacter).count - 1
        
        if numIncomingOneTimeCharacter == 1,
           let originalText = textField.text,
           let range = Range(range, in: originalText)
        {
            validCharacters.formUnion(oneTimeCharacter)
            
            let text = originalText.replacingCharacters(in: range, with: "")
            let numExistingOneTimeCharacters = text.components(separatedBy: oneTimeCharacter).count - 1
            
            guard (numExistingOneTimeCharacters == 0) ? // only 1 oneTimeCharacter allowed
                    (numIncomingOneTimeCharacter <= 1) : (numIncomingOneTimeCharacter == 0) else { return false }
        }
        
        return markDirty(string.rangeOfCharacter(from: validCharacters.inverted) == nil)
    }
}
