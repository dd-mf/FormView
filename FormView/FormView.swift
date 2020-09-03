//
//  FormView.swift
//  FormView
//
//  Created by J.Rodden on 8/10/20.
//

import UIKit

fileprivate extension CGFloat
{
    static let stackSpacing = CGFloat(8)
}

fileprivate extension TimeInterval
{
    static let animationDuration = 0.2
}

// MARK: -

public class FormView: UIScrollView
{
    public private(set) var data: Any?

    private let stack: UIStackView = execute
    {
        let stack = UIStackView()
        
        stack.axis = .vertical
        stack.distribution = .fill
        stack.spacing = .stackSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }
    
    public var values: [String: Any]?
    {
        guard let data = data else { return nil }
        return textFields.reduce([String: Any]())
        {
            let property = $1.property
            guard let value = (data as? _Assignable)?[property.label] ??
                    property.convert($1.textField.text) else { return $0 }
            guard let unwrappedValue = unwrap(value) else { return $0 }
            return $0.merging([property.label: unwrappedValue]) { (_, new) in new }
        }
    }

    private var textFields = [TextFieldInfo]()
    private typealias TextFieldInfo =
        (textField: UITextField, property: Property)
    
    private var pickerView: PickerView?
    private weak var currentTextField: UITextField?
    public weak var textFieldDelegate: UITextFieldDelegate?


    // MARK:
    
    deinit { NotificationCenter.default.removeObserver(self) }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        addSubview(stack)
 
        for notification in
            [UIResponder.keyboardDidShowNotification,
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
    private func property(for textField: UITextField) -> Property?
    {
        textFields.first(where: { $0.textField === textField })?.property
    }
    
    private func createTextField(for property: Mirror.Child) -> UITextField?
    {
        let value = unwrap(property.value)
        guard let property = Property(property, self) else { return nil }

        let textField = UITextField()

        textField.returnKeyType = .next
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        
        if property.label.lowercased()
            .contains("password") == true
        {
            textField.clearsOnInsertion = true
            textField.isSecureTextEntry = true
        }
        
        if let value = value
        {
            textField.text = "\(value)"
        }
        
        textField.placeholder = "\(property.label)"
        
        if let value = value,
            Mirror(reflecting: value).isA(.enum)
        {
            textField.spellCheckingType = .no
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        }

        textField.textColor = .label
        textField.keyboardType = property.keyboardType
        textField.font = .preferredFont(forTextStyle: .body)

        textFields.append((textField: textField, property: property))
        return textField
    }
    
    private func createToolbar(back: Selector = #selector(advanceToPrevTextField),
                               next: Selector = #selector(advanceToNextTextField),
                               done: Selector = #selector(stopEditing)) -> UIToolbar
    {
        let toolbar = UIToolbar()
        defer { toolbar.sizeToFit() }

        toolbar.items = [
            UIBarButtonItem(title: "\u{2191}", style: .plain, target: (self, back)),
            UIBarButtonItem(title: "\u{2193}", style: .plain, target: (self, next)),
            UIBarButtonItem.flexibleSpace, UIBarButtonItem(title: "Done", style: .plain,
                                                           target: self, action: done)
        ]

        return toolbar
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
        data = template
        var labelWidth: CGFloat = 0
        let toolbar = createToolbar()

        defer { textFields.last?.textField.returnKeyType = .done }

        for property in Mirror(reflecting: template).children
        {
            guard let textField = createTextField(for: property) else { continue }
            
            customize?(textField)
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
                    label.font = textField.font
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
    @objc public func stopEditing()
    {
        if currentTextField?.resignFirstResponder() == false
        {
            currentTextField?.textColor = .label

            currentTextField = nil
            assert(pickerView != nil)
            assert(pickerView?.superview != nil)
            
            guard let container = pickerView?.superview else { return }
            
            UIView.animate(withDuration: .animationDuration) {
                container.frame = container.frame.offsetBy(dx: 0, dy: container.frame.height)
            }
            completion: { _ in
                self.pickerView = nil
                container.removeFromSuperview()
                NotificationCenter.default.post(
                    name: UIResponder.keyboardWillHideNotification, object: nil,
                    userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: container.frame)])
            }
        }
    }
    
    /// add/remove extra padding to scrollView.contentSize so everything can be viewed
    @objc private func keyboardChanged(_ notification: Notification)
    {
        guard notification.name == UIResponder.keyboardDidShowNotification else
        {
            return UIView.animate(withDuration: .animationDuration)
            {
                self.contentInset = .zero
                self.scrollIndicatorInsets = .zero
            }
        }
        
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        guard let frameInfo = notification.userInfo?[frameKey],
              let frame = (frameInfo as? NSValue)?.cgRectValue,
              let keyboardFrame = root?.convert(frame, to: self),
              frame.intersects(keyboardFrame) else { return }

        let contentInsets = UIEdgeInsets(top: 0, left: 0,
                                         bottom: keyboardFrame.height, right: 0)
        
        UIView.animate(withDuration: .animationDuration)
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
            textFields[nextIndex % textFields.count].textField.becomeFirstResponder()
        }
    }
    
    private func configurePickerView(in container: UIView, new newPickerView: Bool)
    {
        guard let root = root,
              let pickerView = pickerView else { return }
        
        let toolbar = createToolbar()
        toolbar.items = execute
        {
            let space = { UIBarButtonItem.fixedSpace(20) }
            return [space()] + (toolbar.items ?? []) + [space()]
        }

        root.addSubview(container)
        
        container.layer.borderWidth = 0.5
        container.backgroundColor = .secondarySystemBackground
        container.layer.borderColor = UIColor.opaqueSeparator.cgColor
        
        [toolbar, pickerView].forEach {
            container.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        container.frame = root.bounds
        container.frame.origin.y = root.bounds.height
        container.frame.size.height = pickerView.frame.height +
            toolbar.frame.height + root.safeAreaInsets.bottom
        
        if !newPickerView
        {
            container.frame = container.frame
                .offsetBy(dx: 0, dy: -container.frame.height)
        }
        
        ["H:|[toolbar]|", "H:|[pickerView]|", "V:|[toolbar][pickerView]"].forEach
        {
            root.addConstraints(
                NSLayoutConstraint.constraints(withVisualFormat: $0, metrics: nil,
                                               views: ["toolbar": toolbar,
                                                       "pickerView": pickerView]))
        }
        
        container.addConstraints([NSLayoutConstraint(
                                    item: toolbar,
                                    attribute: .height, relatedBy: .equal,
                                    toItem: nil, attribute: .notAnAttribute,
                                    multiplier: 1, constant: toolbar.frame.height),
                                  NSLayoutConstraint(
                                    item: pickerView,
                                    attribute: .height, relatedBy: .equal,
                                    toItem: nil, attribute: .notAnAttribute,
                                    multiplier: 1, constant: pickerView.frame.height)])
    }
}

// MARK: - UITextFieldDelegate

extension FormView: UITextFieldDelegate
{
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    {
        let match = { (info: TextFieldInfo) in info.textField === textField }
        guard let property = textFields.first(where: match)?.property,
              case let .enum(type) = property.kind else
        {
            if pickerView != nil { stopEditing() }
            return true
        }
        
        guard pickerView != nil || currentTextField?
                .resignFirstResponder() ?? true else { return true }
        
        textField.textColor = .systemBlue
        currentTextField?.textColor = .label
        
        currentTextField = textField
        let newPickerView = pickerView == nil
        
        pickerView = pickerView ?? PickerView()
        pickerView?.components = property.isOptional ?
            [[""] + type.allValues] : [type.allValues]
        
        pickerView?.currentSelection = textField.text
        pickerView?.selectionChanged = {
            [weak self, weak textField] (picker, _) in
            guard let self = self else { return }
            
            textField?.text = picker.currentSelection as? String
            
            if var data = self.data as? _Assignable
            {
                let newValue = property.convert(textField?.text)
                self.data = data.set(property, to: newValue)
            }
        }
        
        let container = pickerView?.superview ?? UIView()
        guard let root = root, let _ = self.pickerView else { return true }

        if newPickerView
        {
            configurePickerView(in: container, new: newPickerView)
        }

        UIView.animate(withDuration: newPickerView ? .animationDuration : 0)
        {
            container.frame.origin.y = root.bounds.maxY - container.frame.height
        }
        completion:
        {
            _ in NotificationCenter.default.post(
                name: UIResponder.keyboardDidShowNotification, object: nil,
                userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: container.frame)])
        }

        return false
    }
    
    // ensure textField is visible above virtual keyboard
    public func textFieldDidBeginEditing(_ textField: UITextField)
    {
        currentTextField = textField
        
        if let toolbarItems =
            (textField.inputAccessoryView as? UIToolbar)?.items
        {
            toolbarItems[0].isEnabled = textField != textFields.first?.textField
            toolbarItems[1].isEnabled = textField != textFields.last?.textField
        }

        let textFrame = convert(textField.frame, from: textField)
        if !bounds.inset(by: contentInset).contains(textFrame)
        {
            scrollRectToVisible(textFrame, animated: true)
        }
    }

    public func textFieldDidEndEditing(_: UITextField) { currentTextField = nil }
    
    public func textFieldShouldClear(_ textField: UITextField ) -> Bool
    {
        if var data = self.data as? _Assignable,
           let property = property(for: textField)
        {
            let newValue = property.convert("")
            self.data = data.set(property, to: newValue)
        }
        return true
    }
    
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
        let update: (Bool) -> (Bool) = {
            if $0, let original = textField.text,
               let range = Range(range, in: original)
            {
                textField.text = original
                    .replacingCharacters(in: range, with: string)
            }
            if var data = self.data as? _Assignable,
               let property = self.property(for: textField)
            {
                let newValue = property.convert(textField.text)
                self.data = data.set(property, to: newValue)
            }
            return false
        }
        
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
            return update(incomingStringOnlyContains([.urlUserAllowed,
                                                         .urlHostAllowed,
                                                         .urlPathAllowed,
                                                         .urlQueryAllowed,
                                                         .urlFragmentAllowed,
                                                         .urlPasswordAllowed]))
            
        case .asciiCapable, .numbersAndPunctuation:
            return update(incomingStringOnlyContains([.alphanumerics,
                                                         .punctuationCharacters]))
            
        case .asciiCapableNumberPad, .numberPad:
            return update(incomingStringOnlyContains([.decimalDigits]))

        case .phonePad:
            guard incomingStringOnlyContains([.decimalDigits]) else { return update(false) }
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
                
                _ = update(originalText != textField.text)
            }
            
            return false
            
        default: return update(true) // anything goes
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
        
        return update(string.rangeOfCharacter(from: validCharacters.inverted) == nil)
    }
}
