//
//  DatePickerConfig.swift
//  FormView
//
//  Created by J.Rodden on 9/2/20.
//

import UIKit

public class DatePicker: UIPickerView
{
    public struct Format
    {
        var format = "E MMM d, h:mm a"
        var locale: Locale = .current
        var calendar: Calendar = .current
        var timeZone: TimeZone = .current
    }
    
    public struct Config
    {
        var mode: Mode = .dateAndTime

        var minimumDate: Date?
        var maximumDate: Date?
        
        var minuteInterval: Int = 1
        
        var preferredStyle: UIDatePickerStyle = .wheels
        
        public enum Mode : Int
        {
            case time, date, dateAndTime
            
            internal var datePickerMode: UIDatePicker.Mode
            {
                switch self
                {
                case .time: return .time
                case .date: return .date
                case .dateAndTime: return .dateAndTime
                }
            }
        }
    }
}

// MARK: -

extension DateFormatter
{
    convenience init(_ format: DatePicker.Format)
    {
        self.init()
        locale = format.locale
        dateFormat = format.format
        calendar = format.calendar
        timeZone = format.timeZone
    }
}
