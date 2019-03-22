//
//  Model.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


struct ChartDataEntry {
    var x: TimeInterval
    var y: Int
}

struct ChartDataSet {
    var values: [ChartDataEntry]
    var name: String
    var color: UIColor
    
    static func parse(jsonData: Data) -> [[ChartDataSet]] {
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
            let json = jsonObject as? [[String: AnyObject]]
            else {
                return []
        }
        func column<T>(from json: [[AnyObject]], at key: String) -> [T]? {
            return json.first(where: { $0.first as? String == key })?
                .enumerated().compactMap({ (index: Int, element: AnyObject) -> T? in
                    guard index > 0, let element = element as? T else { return nil }
                    return element
                })
        }
        
        var charts = [[ChartDataSet]]()
        for chartJson in json {
            guard
                let columns = chartJson["columns"] as? [[AnyObject]],
                let types = chartJson["types"] as? [String:String],
                let names = chartJson["names"] as? [String:String],
                let colors = chartJson["colors"] as? [String:String],
                let x = types.first(where: { $1 == "x" })?.key,
                let xColumn = column(from: columns, at: x) as [TimeInterval]?
                else { continue }
            var dataSets = [ChartDataSet]()
            for (key, type) in types where type == "line" {
                guard
                    let column = column(from: columns, at: key) as [Int]?,
                    column.count == xColumn.count,
                    let name = names[key],
                    let hexColor = colors[key]
                    else { continue }
                
                dataSets.append(ChartDataSet(values: zip(xColumn, column).map({ ChartDataEntry(x: $0/1000, y: $1) }).sorted(by: { $0.x < $1.x }),
                                             name: name,
                                             color: UIColor(hex: hexColor)))
            }
            charts.append(dataSets.sorted(by: { $0.name < $1.name }))
        }
        
        return charts
    }
    
    static func chartImage(_ chart: [ChartDataSet], size: CGSize, lineWidth: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        var minDataEntry = chart.first!.values.first!
        var maxDataEntry = chart.first!.values.first!
        
        for dataSet in chart {
            for dataEntry in dataSet.values {
                minDataEntry.x = min(minDataEntry.x, dataEntry.x)
                minDataEntry.y = min(minDataEntry.y, dataEntry.y)
                maxDataEntry.x = max(maxDataEntry.x, dataEntry.x)
                maxDataEntry.y = max(maxDataEntry.y, dataEntry.y)
            }
        }
        for dataSet in chart {
            context.setLineWidth(lineWidth)
            context.setStrokeColor(dataSet.color.cgColor)
            context.setLineJoin(.round)
            context.setFlatness(0.1)
            context.setLineCap(.round)
            
            let points = dataSet.values.map({ CGPoint(x: lineWidth / 2 + CGFloat($0.x - minDataEntry.x) / CGFloat(maxDataEntry.x - minDataEntry.x) * (size.width - lineWidth),
                                                      y: lineWidth / 2 + (1 - CGFloat($0.y - minDataEntry.y) / CGFloat(maxDataEntry.y - minDataEntry.y)) * (size.height - lineWidth)) })
            context.addLines(between: points)
            context.strokePath()
        }
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

