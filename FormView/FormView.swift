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

public protocol FormViewDelegate: UIScrollViewDelegate, UITextFieldDelegate
{
    func dateFormat(for key: String?) -> DatePicker.Format
    func dateConfiguration(for key: String?) -> DatePicker.Config
}

extension FormViewDelegate
{
    func dateFormat(for key: String?) -> DatePicker.Format { DatePicker.Format() }
    func dateConfiguration(for key: String?) -> DatePicker.Config { DatePicker.Config() }
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
    
    private var pickerView: (forDate: UIDatePicker?,
                             forString: PickerView?)
    {
        didSet { assert(pickerView.forDate == nil ||
                            pickerView.forString == nil) }
    }
    
    private weak var currentTextField: UITextField?

    var formViewDelegate: FormViewDelegate? { delegate as? FormViewDelegate }

    // MARK:
    
    deinit { NotificationCenter.default.removeObserver(self) }
    
    private func set<T>(_ property: Property, to value: T?)
    {
        if var data = data as? _Assignable
        {
            self.data = data.set(property, to: value)
        }
    }
    
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

// MARK: - Configuration

extension FormView
{
    private func embed(_ view: UIView, in container: UIView)
    {
        guard let root = root else { return }
        
        root.addSubview(container)
        let toolbar = createToolbar()
        
        toolbar.items = execute
        {
            let space = { UIBarButtonItem.fixedSpace(20) }
            return [space()] + (toolbar.items ?? []) + [space()]
        }

        [toolbar, view].forEach {
            container.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        container.frame = root.bounds
        container.frame.origin.y = root.bounds.height
        container.frame.size.height = view.frame.height +
            toolbar.frame.height + root.safeAreaInsets.bottom
        
        container.layer.borderWidth = 0.5
        container.backgroundColor = .secondarySystemBackground
        container.layer.borderColor = UIColor.opaqueSeparator.cgColor

        ["H:|[toolbar]|", "H:|[picker]|", "V:|[toolbar][picker]"].forEach
        {
            root.addConstraints(
                NSLayoutConstraint.constraints(withVisualFormat: $0, metrics: nil,
                                               views: ["toolbar": toolbar, "picker": view]))
        }
        
        container.addConstraints([NSLayoutConstraint(
                                    item: toolbar,
                                    attribute: .height, relatedBy: .equal,
                                    toItem: nil, attribute: .notAnAttribute,
                                    multiplier: 1, constant: toolbar.frame.height),
                                  NSLayoutConstraint(
                                    item: view,
                                    attribute: .height, relatedBy: .equal,
                                    toItem: nil, attribute: .notAnAttribute,
                                    multiplier: 1, constant: view.frame.height)])
    }

    private func property(for textField: UITextField) -> Property?
    {
        textFields.first(where: { $0.textField === textField })?.property
    }
    
    private func pickerCreator(for textField: UITextField) -> (() -> (UIView?))?
    {
        guard let property = property(for: textField) else { return nil }
        
        switch property.kind
        {
        case let .enum(type):
            return {
                let pickerView = self.pickerView.forString ?? PickerView()
                defer { self.pickerView = (forDate: nil, forString: pickerView) }

                // add an empty entry if property is optional
                pickerView.components = property.isOptional ?
                    [[""] + type.allValues] : [type.allValues]
                
                pickerView.currentSelection = textField.text
                pickerView.selectionChanged = {
                    [weak self, weak textField] (picker, _) in
                    textField?.text = picker.currentSelection as? String
                    self?.set(property, to: property.convert(textField?.text))
                }

                return pickerView
            }
            
        case .date(let config, let formatter): return {
            defer { // force textField.text to be updated upon exit
                self.currentTextField = textField; self.datePickerChanged()
            }
            
            let datePicker = self.pickerView.forDate ?? UIDatePicker()
            defer { self.pickerView = (forDate: datePicker, forString: nil) }

            datePicker.locale = formatter.locale
            datePicker.calendar = formatter.calendar
            datePicker.timeZone = formatter.timeZone
            datePicker.minimumDate = config.minimumDate
            datePicker.maximumDate = config.maximumDate
            datePicker.minuteInterval = config.minuteInterval
            datePicker.datePickerMode = config.mode.datePickerMode

            datePicker.date =
                (self.data as? _Assignable)?[property.label] as? Date ??
                property.convert(textField.text) as? Date ?? Date()

            if #available(iOS 13.4, *) {
                datePicker.preferredDatePickerStyle = config.preferredStyle
            }

            datePicker.addTarget((self, #selector(
                                    self.datePickerChanged)), for: .valueChanged)
            return datePicker
        }
        
        default: return nil
        }
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
    
    public func populate<T>(for template: T,
                            editable: Bool = true,
                            labels: LabelStyle = .default,
                            customize: ((UIView)->())? = nil )
    {
        stopEditing()
        data = template
        textFields.removeAll()
        stack.removeAllSubviews()
        
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

// MARK: - Event Handling

extension FormView
{
    @objc public func stopEditing()
    {
        if currentTextField?.resignFirstResponder() == false
        {
            defer { currentTextField = nil }
            currentTextField?.textColor = .label

            assert(pickerView.forDate ?? pickerView.forString != nil)
            assert((pickerView.forDate ?? pickerView.forString)?.superview != nil)

            guard let container = (pickerView.forDate ??
                                    pickerView.forString)?.superview else { return }

            UIView.animate(withDuration: .animationDuration) {
                container.frame = container.frame.offsetBy(dx: 0, dy: container.frame.height)
            }
            completion: { _ in
                container.removeFromSuperview()
                self.pickerView = (forDate: nil, forString: nil)

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
    
    @objc private func datePickerChanged()
    {
        if let date = pickerView.forDate?.date,
           let currentTextField = currentTextField,
           let property = property(for: currentTextField)
        {
            if let dateString = property.string(from: date)
            {
                set(property, to: date)
                currentTextField.text = dateString
            }
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
}

// MARK: - UITextFieldDelegate

extension FormView: UITextFieldDelegate
{
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    {
        let previousPicker = pickerView.forDate ?? pickerView.forString

        guard let root = root, // does this textField need a picker?
              let createPicker = pickerCreator(for: textField)
        else { if previousPicker != nil { stopEditing() }; return true }
        
        guard previousPicker != nil || currentTextField?
                .resignFirstResponder() ?? true else { return true }
        
        currentTextField?.textColor = .label

        guard let currentPicker = createPicker() else { return true }

        currentTextField = textField
        currentTextField?.textColor = .systemBlue
        
        let newPicker = currentPicker != previousPicker
        let container = previousPicker?.superview ?? UIView()

        if newPicker
        {
            embed(currentPicker, in: container)
            previousPicker?.removeFromSuperview()
        }

        UIView.animate(withDuration: newPicker ? .animationDuration : 0)
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
        if let property = property(for: textField)
        {
            set(property, to: property.convert(""))
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
            if let property = self.property(for: textField)
            {
                self.set(property, to: property.convert(textField.text))
            }
            return false
        }
        
        let incomingStringOnlyContains: ([CharacterSet]) -> Bool = {
            let validCharacters = $0.reduce(CharacterSet()) { $0.union($1) }
            return string.rangeOfCharacter(from: validCharacters.inverted) == nil
        }
        
        switch textField.keyboardType
        {
        case .emailAddress:
            validCharacters = CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: ".-"))
            oneTimeCharacter = CharacterSet(charactersIn: "@")
            
        case .decimalPad:
            validCharacters = .decimalDigits
            oneTimeCharacter = CharacterSet(charactersIn: Locale.current
                                                .decimalSeparator ?? ".")

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
                let modifiedText = originalText.replacingCharacters(in: range, with: string)
                    .components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                
                textField.text = Locale.current.formattedPhoneNumber(modifiedText)
                
                if originalText != textField.text { _ = update(false) }
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
