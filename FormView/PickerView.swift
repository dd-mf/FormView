//
//  PickerView.swift
//  FormView
//
//  Created by J.Rodden on 8/25/20.
//

import UIKit

extension String: PickerViewOption { }

public protocol PickerViewOption: CustomStringConvertible
{
    func equals(_ other: PickerViewOption) -> Bool
}

public extension PickerViewOption where Self: Equatable
{
    func equals(_ other: PickerViewOption) -> Bool
    {
        if let other = other as? Self
        { return self == other } else { return false }
    }
}

// MARK: -

public class PickerView: UIPickerView
{
    typealias Component = Int

    override init(frame: CGRect)
    {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit()
    {
        delegate = self
        dataSource = self
    }
    
    var components: [[PickerViewOption]] = [[String]]()
    {
        didSet
        {
            defer { reloadAllComponents() }
            selectedRow = [Component](repeating: 0, count:
                                        numberOfComponents(in: self))
        }
    }

    private var selectedRow = [Int]()
    
    var currentSelection: PickerViewOption?
    {
        get { components.count == 1 ? selectedOption(for: 0) : nil }
        set
        {
            guard components.count == 1 else { return }
            guard let newValue = newValue else { return }
            
            if let index = components[0]
                .firstIndex(where: { $0.equals(newValue) })
            {
                selectedRow[0] = index
                selectRow(index, inComponent: 0, animated: true)
            }
        }
    }
    
    var selectionChanged: ((PickerView, Component)->())?
    
    func selectedOption(for component: Component) -> PickerViewOption?
    {
        (component >= 0 && component < components.count) ?
            components[component][selectedRow[component]] : nil
    }
}

// MARK: - UIPickerViewDelegate

extension PickerView: UIPickerViewDelegate
{
    public func pickerView(_ pickerView: UIPickerView,
                           titleForRow row: Int, forComponent component: Int) -> String?
    {
        guard component >= 0, component < components.count else { return nil }
        guard row >= 0, row < components[component].count else { return nil }
        return "\(components[component][row])"
    }
    
//    func pickerView(_ pickerView: UIPickerView,
//                    attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString?
//    {
//    }
    
//    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
//                    forComponent component: Int, reusing view: UIView?) -> UIView
//    {
//    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        if component >= 0, component < components.count {
            selectedRow[component] = row; selectionChanged?(self, component)
        }
    }
}

// MARK: - UIPickerViewDataSource

extension PickerView: UIPickerViewDataSource
{
    public func numberOfComponents(in pickerView: UIPickerView) -> Int { components.count }
    
    public func pickerView(_ pickerView: UIPickerView,
                           numberOfRowsInComponent component: Int) -> Int
    {
        (component >= 0 && component < components.count) ? components[component].count : 0
    }
}


