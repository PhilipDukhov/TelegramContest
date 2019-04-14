//
//  Model.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


class ChartDataEntry: NSObject, NSCoding {
    let x: TimeInterval
    let y: Int
    
    init(x: TimeInterval, y: Int) {
        self.x = x
        self.y = y
    }
    
    required init?(coder aDecoder: NSCoder) {
        y = aDecoder.decodeInteger(forKey: "y")
        x = aDecoder.decodeDouble(forKey: "x")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(x, forKey: "x")
        aCoder.encode(y, forKey: "y")
    }
}

class ChartData: NSObject, NSCoding {
    let y_scaled: Bool
    let percentage: Bool
    let stacked: Bool
    let name: String
    let dataSets: [ChartDataSet]
    let type: ChartDataSet.ChartType
    
    private var _stackedDataSets: [(TimeInterval, [Int])]?
    var stackedDataSets: [(TimeInterval, [Int])]? {
        guard stacked && !percentage else {return nil}
        if _stackedDataSets != nil {
            return _stackedDataSets
        }
        _stackedDataSets = [(TimeInterval, [Int])]()
        for i in 0..<dataSets[0].values.count {
            var values = [Int]()
            for dataSet in dataSets where dataSet.selected {
                values.append(dataSet.values[i].y)
            }
            _stackedDataSets!.append((dataSets[0].values[i].x, values))
        }
        return _stackedDataSets
    }
    
    private var _stackedPercentedDataSets: [(TimeInterval, [CGFloat])]?
    var stackedPercentedDataSets: [(TimeInterval, [CGFloat])]? {
        guard stacked && percentage else {return nil}
        if _stackedPercentedDataSets != nil {
            return _stackedPercentedDataSets
        }
        _stackedPercentedDataSets = [(TimeInterval, [CGFloat])]()
        for i in 0..<dataSets[0].values.count {
            var values = [Int]()
            for dataSet in dataSets where dataSet.selected {
                values.append(dataSet.values[i].y)
            }
            let multiplier = 100 / CGFloat(values.reduce(0, +))
            _stackedPercentedDataSets!.append((dataSets[0].values[i].x, values.map { CGFloat($0) * multiplier }))
        }
        return _stackedPercentedDataSets
    }
    
    init(name: String,
         y_scaled: Bool,
         percentage: Bool,
         stacked: Bool,
         dataSets: [ChartDataSet])
    {
        self.name = name
        self.y_scaled = y_scaled
        self.percentage = percentage
        self.stacked = stacked
        self.dataSets = dataSets
        type = dataSets[0].type
    }
    
    required init?(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObject(forKey: "name") as! String
        y_scaled = aDecoder.decodeBool(forKey: "y_scaled")
        percentage = aDecoder.decodeBool(forKey: "percentage")
        stacked = aDecoder.decodeBool(forKey: "stacked")
        dataSets = aDecoder.decodeObject(forKey: "dataSets") as! [ChartDataSet]
        type = dataSets[0].type
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(y_scaled, forKey: "y_scaled")
        aCoder.encode(percentage, forKey: "percentage")
        aCoder.encode(stacked, forKey: "stacked")
        aCoder.encode(dataSets, forKey: "dataSets")
    }
    
    static func parse(rootDir: URL) -> [ChartData]? {
        guard let dirNames = (try? FileManager.default.contentsOfDirectory(atPath: rootDir.path))?.sorted() else {
            return nil
        }
        var result = [ChartData]()
        var dateComponents = DateComponents()
        let userCalendar = Calendar.current
        for dirName in dirNames {
            let dirURL = rootDir.appendingPathComponent(dirName)
            let overviewURL = dirURL.appendingPathComponent("overview.json")
            var subvalues = [TimeInterval: ChartData]()
            guard
                let jsonData = try? Data(contentsOf: overviewURL),
                let dateDirNames = (try? FileManager.default.contentsOfDirectory(atPath: dirURL.path))?.sorted() else {
                    return nil
            }
            for dateDirName in dateDirNames {
                let dateComponentStrings = dateDirName.split(separator: "-")
                guard dateComponentStrings.count == 2 else { continue }
                dateComponents.year = Int(dateComponentStrings[0])
                dateComponents.month = Int(dateComponentStrings[1])
                let dateDirURL = dirURL.appendingPathComponent(dateDirName)
                guard let dayFileNames = (try? FileManager.default.contentsOfDirectory(atPath: dateDirURL.path))?.sorted() else {
                    return nil
                }
                for dayFileName in dayFileNames {
                    guard let dayNumberString = dayFileName.split(separator: ".").first,
                        let dayNumber = Int(dayNumberString), dayNumber > 0,
                        let jsonData = try? Data(contentsOf: dateDirURL.appendingPathComponent(dayFileName))
                        else {
                            return nil
                    }
                    dateComponents.day = dayNumber
                    let timestamp = -userCalendar.date(from: dateComponents)!.timeIntervalSince1970
                    subvalues[timestamp] = ChartDataSet.parse(jsonData: jsonData)!
                }
            }
            result.append(ChartDataSet.parse(jsonData: jsonData)!)
        }
        return result
    }
        
    func selectionUpdated() {
        _stackedDataSets = nil
        _stackedPercentedDataSets = nil
    }
}

class ChartDataSet: NSObject, NSCoding {
    enum ChartType: String {
        case line = "line"
        case bar = "bar"
        case area = "area"
    }
    
    let values: [ChartDataEntry]
    let subvalues: [TimeInterval: ChartDataSet]?
    let name: String
    let color: UIColor
    let type: ChartType
    var selected = true
    
    init(values: [ChartDataEntry],
         subvalues: [TimeInterval: ChartDataSet]?,
         name: String,
         color: UIColor,
         type: ChartType)
    {
        self.values = values
        self.subvalues = subvalues
        self.name = name
        self.color = color
        self.type = type
    }
    
    required init?(coder aDecoder: NSCoder) {
        values = aDecoder.decodeObject(forKey: "values") as! [ChartDataEntry]
        subvalues = aDecoder.decodeObject(forKey: "subvalues") as? [TimeInterval: ChartDataSet]
        name = aDecoder.decodeObject(forKey: "name") as! String
        color = aDecoder.decodeObject(forKey: "color") as! UIColor
        type = ChartType(rawValue: aDecoder.decodeObject(forKey: "type") as! String)!
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(values, forKey: "values")
        aCoder.encode(subvalues, forKey: "subvalues")
        aCoder.encode(name, forKey: "name")
        aCoder.encode(color, forKey: "color")
        aCoder.encode(type.rawValue, forKey: "type")
    }
    
    static func parse(jsonData: Data, subvalues: [TimeInterval: ChartDataSet]? = nil) -> ChartData? {
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
            let json = jsonObject as? [String: AnyObject]
            else {
                return nil
        }
        func column<T>(from json: [[AnyObject]], at key: String) -> [T]? {
            return json.first(where: { $0.first as? String == key })?
                .enumerated().compactMap({ (index: Int, element: AnyObject) -> T? in
                    guard index > 0, let element = element as? T else { return nil }
                    return element
                })
        }
        let stacked = json["stacked"] as? Bool == true
        guard
            let columns = json["columns"] as? [[AnyObject]],
            let typesDict = (json["types"] as? [String:String])?.sorted(by: { $0.0 < $1.0 }),
            let colors = json["colors"] as? [String:String],
            let names = json["names"] as? [String:String],
            let x = typesDict.first(where: { $1 == "x" })?.key,
            let xColumn = column(from: columns, at: x) as [TimeInterval]?
            else { return nil }
        var dataSets = [ChartDataSet]()
        for (key, type) in typesDict where key != x {
            guard let type = ChartType(rawValue: type) else { continue }
            guard
                let column = column(from: columns, at: key) as [Int]?,
                column.count == xColumn.count,
                let name = names[key],
                let hexColor = colors[key]
                else {
                    return nil
            }
            dataSets.append(ChartDataSet(values: zip(xColumn, column).map({ ChartDataEntry(x: $0/1000, y: $1) }).sorted(by: { $0.x < $1.x }),
                                         subvalues: subvalues,
                                         name: name,
                                         color: UIColor(hex: hexColor),
                                         type: type))
        }
        return ChartData(name: json["name"] as? String ?? "",
                         y_scaled: json["y_scaled"] as? Bool == true,
                         percentage: json["percentage"] as? Bool == true,
                         stacked: stacked,
                         dataSets: dataSets)
    }
}

