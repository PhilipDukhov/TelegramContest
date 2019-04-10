//
//  Model.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


class ChartDataEntry: NSObject, NSCoding {
    var copy: ChartDataEntry {
        return ChartDataEntry(x: x, y: y)
    }
    
    var x: TimeInterval
    var y: Int
    
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

class ChartDataSet: NSObject, NSCoding {
    enum ChartType: String {
        case line = "line"
        case bar = "bar"
        case area = "area"
    }
    
    var values: [ChartDataEntry]
    var subvalues: [TimeInterval: ChartDataSet]?
    var name: String
    var color: UIColor
    var type: ChartType
    var y_scaled: Bool
    var percentage: Bool
    var stacked: Bool
    
    init(values: [ChartDataEntry],
         subvalues: [TimeInterval: ChartDataSet]?,
         name: String,
         color: UIColor,
         type: ChartType,
         y_scaled: Bool,
         percentage: Bool,
         stacked: Bool)
    {
        self.values = values
        self.subvalues = subvalues
        self.name = name
        self.color = color
        self.type = type
        self.y_scaled = y_scaled
        self.percentage = percentage
        self.stacked = stacked
    }
    
    required init?(coder aDecoder: NSCoder) {
        values = aDecoder.decodeObject(forKey: "values") as! [ChartDataEntry]
        subvalues = aDecoder.decodeObject(forKey: "subvalues") as? [TimeInterval: ChartDataSet]
        name = aDecoder.decodeObject(forKey: "name") as! String
        color = aDecoder.decodeObject(forKey: "color") as! UIColor
        type = ChartType(rawValue: aDecoder.decodeObject(forKey: "type") as! String)!
        y_scaled = aDecoder.decodeBool(forKey: "y_scaled")
        percentage = aDecoder.decodeBool(forKey: "percentage")
        stacked = aDecoder.decodeBool(forKey: "stacked")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(values, forKey: "values")
        aCoder.encode(subvalues, forKey: "subvalues")
        aCoder.encode(name, forKey: "name")
        aCoder.encode(color, forKey: "color")
        aCoder.encode(type.rawValue, forKey: "type")
        aCoder.encode(y_scaled, forKey: "y_scaled")
        aCoder.encode(percentage, forKey: "percentage")
        aCoder.encode(stacked, forKey: "stacked")
    }
    
    static func parse(rootDir: URL) -> [[ChartDataSet]]? {
        guard let dirNames = (try? FileManager.default.contentsOfDirectory(atPath: rootDir.path))?.sorted() else {
            return nil
        }
        var result = [[ChartDataSet]]()
        var dateComponents = DateComponents()
        let userCalendar = Calendar.current
        for dirName in dirNames {
            let dirURL = rootDir.appendingPathComponent(dirName)
            let overviewURL = dirURL.appendingPathComponent("overview.json")
            var subvalues = [TimeInterval: [ChartDataSet]]()
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
                    let data = ChartDataSet.parse(jsonData: jsonData)!
                    subvalues[timestamp] = data
                }
            }
            result.append(ChartDataSet.parse(jsonData: jsonData)!)
        }
        return result
    }
    
    static func parse(jsonData: Data, subvalues: [TimeInterval: ChartDataSet]? = nil) -> [ChartDataSet]? {
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
        
        guard
            let columns = json["columns"] as? [[AnyObject]],
            let types = json["types"] as? [String:String],
            let colors = json["colors"] as? [String:String],
            let names = json["names"] as? [String:String],
            let x = types.first(where: { $1 == "x" })?.key,
            let xColumn = column(from: columns, at: x) as [TimeInterval]?
            else { return nil }
        var dataSets = [ChartDataSet]()
        for (key, type) in types where type != "x" {
            guard
                let type = ChartType(rawValue: type),
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
                                         type: type,
                                         y_scaled: json["y_scaled"] as? Bool == true,
                                         percentage: json["percentage"] as? Bool == true,
                                         stacked: json["stacked"] as? Bool == true))
        }
        
        return dataSets.sorted(by: { $0.name < $1.name })
    }
    
    static func chartImage(_ chart: [ChartDataSet], size: CGSize, lineWidth: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let minDataEntry = chart.first!.values.first!.copy
        let maxDataEntry = chart.first!.values.first!.copy
        
        for dataSet in chart {
            for dataEntry in dataSet.values {
                minDataEntry.x = min(minDataEntry.x, dataEntry.x)
                minDataEntry.y = min(minDataEntry.y, dataEntry.y)
                maxDataEntry.x = max(maxDataEntry.x, dataEntry.x)
                maxDataEntry.y = max(maxDataEntry.y, dataEntry.y)
            }
        }
        let xMultiplier = (size.width - lineWidth) / CGFloat(maxDataEntry.x - minDataEntry.x)
        let yRangeLength = CGFloat(maxDataEntry.y - minDataEntry.y)
        let height = size.height - lineWidth
        for dataSet in chart {
            context.setLineWidth(lineWidth)
            context.setStrokeColor(dataSet.color.cgColor)
            context.setLineJoin(.round)
            context.setFlatness(0.1)
            context.setLineCap(.round)
            
            let points = dataSet.values.map({ CGPoint(x: lineWidth / 2 + CGFloat($0.x - minDataEntry.x) * xMultiplier,
                                                      y: lineWidth / 2 + (1 - CGFloat($0.y - minDataEntry.y) / yRangeLength) * height) })
            context.addLines(between: points)
            context.strokePath()
        }
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

