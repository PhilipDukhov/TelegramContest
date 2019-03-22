//
//  StatisticsViewController.swift
//  TelegramContest
//
//  Created by Philip on 3/16/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


class StatisticsViewController: UIViewController {
    private static let chartCellHeight: CGFloat = 309
    private static let chartSliderCellHeight: CGFloat = 64
    
    var charts = [[ChartDataSet]]()
    var displayedCharts = [IndexSet]()
    var visibleSegments = [Segment]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let jsonPath = Bundle.main.path(forResource: "chart_data", ofType: "json"),
            let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath))
        {
            charts = ChartDataSet.parse(jsonData: jsonData)
//            charts = [charts.first!]

            displayedCharts = charts.map({ IndexSet(integersIn: 0..<$0.count) })
            visibleSegments = Array(repeating: Segment(start: 0, end: 1), count: charts.count)
        }
    }
}

extension StatisticsViewController: UITableViewDataSource {    
    func numberOfSections(in tableView: UITableView) -> Int {
        return charts.count + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < charts.count else {
            return 1
        }
        return charts[section].count + 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < charts.count else { return nil }
        return "Followers"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < charts.count else {
            return tableView.dequeueReusableCell(withIdentifier: "NightMode")!
        }
        let chart = charts[indexPath.section]
        let selectedCharts = chart.enumerated().compactMap { displayedCharts[indexPath.section].contains($0) ? $1 : nil }
        let visibleSegment = visibleSegments[indexPath.section]
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: ChartTableViewCell.reuseIdentifier) as! ChartTableViewCell
            cell.chartView.chartData = selectedCharts
            cell.chartView.visibleSegment = visibleSegment
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: SliderTableViewCell.reuseIdentifier) as! SliderTableViewCell
            cell.sliderView.minSelectedValue = CGFloat(visibleSegment.start)
            cell.sliderView.maxSelectedValue = CGFloat(visibleSegment.end)
            cell.sliderView.backgroundView.image = ChartDataSet.chartImage(selectedCharts,
                                                                           size: cell.sliderView.backgroundView.frame.size,
                                                                           lineWidth: cell.sliderView.backgroundView.frame.size.height/60)
            cell.valueChangedHandler = { [weak self] in
                guard
                    let strongSelf = self,
                    let chartCell = tableView.cellForRow(at: IndexPath(row: 0, section: indexPath.section)) as? ChartTableViewCell
                    else { return }
                let segment = Segment(start: TimeInterval(cell.sliderView!.minSelectedValue),
                                      end: TimeInterval(cell.sliderView!.maxSelectedValue))
                strongSelf.visibleSegments[indexPath.section] = segment
                chartCell.chartView.visibleSegment = segment
            }
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: SelectionTableViewCell.reuseIdentifier) as! SelectionTableViewCell
            let dataSet = chart[indexPath.row - 2]
            cell.titleLabel.text = dataSet.name
            cell.colorMarkView.backgroundColor = dataSet.color
            cell.accessoryType = displayedCharts[indexPath.section].contains(indexPath.row - 2) ? .checkmark : .none
            cell.separatorView.isHidden = indexPath.row - 2 == chart.count - 1
            return cell
        }
    }
}

extension StatisticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section < charts.count {
            if indexPath.row == 0 {
                return StatisticsViewController.chartCellHeight
            }
            if indexPath.row == 1 {
                return StatisticsViewController.chartSliderCellHeight
            }
        }
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < charts.count else {
            //            night mode code
            return
        }
        if indexPath.row > 1 {
            let index = indexPath.row - 2
            if displayedCharts[indexPath.section].contains(index) {
                if displayedCharts[indexPath.section].count > 1 {
                    displayedCharts[indexPath.section].remove(index)
                }
                else {
                    let alertVC = UIAlertController(title: "At least one chart should be selected",
                                                    message: nil,
                                                    preferredStyle: .alert)
                    alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    present(alertVC, animated: true, completion: nil)
                    return
                }
            }
            else {
                displayedCharts[indexPath.section].insert(index)
            }
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        }
    }
}
