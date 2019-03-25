//
//  StatisticsViewController.swift
//  TelegramContest
//
//  Created by Philip on 3/16/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class ParentCell: UITableViewCell {
    class var reuseIdentifier: String { return "" }
    
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            backgroundColor = presentationTheme.cellBackgroundColor
        }
    }
}


class StatisticsViewController: UIViewController {
    private static let themeUDKey = "isDarkTheme"
    
    private static let chartCellHeight: CGFloat = 309
    private static let chartSliderCellHeight: CGFloat = 64
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var navigationBarSeparatorView: UIView!
    @IBOutlet weak var navigationBarTitleLabel: UILabel!
    
    var charts = [[ChartDataSet]]()
    var displayedCharts = [IndexSet]()
    var visibleSegments = [Segment]()
    var selectedDates = [Int:TimeInterval]()
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            presentationThemeUpdated()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBarSeparatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        let isDark = UserDefaults.standard.bool(forKey: StatisticsViewController.themeUDKey) == true
        presentationTheme = isDark ? PresentationTheme.nightTheme : PresentationTheme.dayTheme 
        if let jsonPath = Bundle.main.path(forResource: "chart_data", ofType: "json"),
            let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath))
        {
            charts = ChartDataSet.parse(jsonData: jsonData)
//            charts = [charts[2]]

            displayedCharts = charts.map({ IndexSet(integersIn: 0..<$0.count) })
            visibleSegments = Array(repeating: Segment(start: 0, end: 1), count: charts.count)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return presentationTheme?.statusBarStyle ?? super.preferredStatusBarStyle
    }
    
    func presentationThemeUpdated() {
        tableView.backgroundColor = presentationTheme.tableViewBackgroundColor
        tableView.reloadData()
        navigationBarView.backgroundColor = presentationTheme.cellBackgroundColor
        navigationBarTitleLabel.textColor =  presentationTheme.selectionTitleTextColor
        navigationBarSeparatorView.backgroundColor = presentationTheme.navigationBarSeparatorColor
        setNeedsStatusBarAppearanceUpdate()
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < charts.count else { return nil }
        let view = UIView()
        let label = UILabel()
        view.addSubview(label)
        
        let attributedString = NSMutableAttributedString(string: "FOLLOWERS")
        attributedString.addAttribute(NSAttributedString.Key.kern, value: 0.05, range: NSMakeRange(0, attributedString.length))
        label.attributedText = attributedString
        
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = presentationTheme.headerTextColor
        label.sizeToFit()
        label.frame = CGRect(origin: CGPoint(x: 15, y: -5), size: label.frame.size)
        view.frame = CGRect(x: 0, y: 0, width: label.frame.maxX, height: label.frame.maxY + 8)
        
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.tableView(tableView, viewForHeaderInSection: section)?.frame.height ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ParentCell
        defer {
            configure(cell: cell, forRowAt: indexPath)
        }
        guard indexPath.section < charts.count else {
            cell = tableView.dequeueReusableCell(withIdentifier: NightModeTableViewCell.reuseIdentifier) as! NightModeTableViewCell
            return cell
        }
        switch indexPath.row {
        case 0:
            cell = tableView.dequeueReusableCell(withIdentifier: ChartTableViewCell.reuseIdentifier) as! ChartTableViewCell
            return cell
            
        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: SliderTableViewCell.reuseIdentifier) as! SliderTableViewCell
            return cell
            
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: SelectionTableViewCell.reuseIdentifier) as! SelectionTableViewCell
            return cell
        }
    }
    
    private func configure(cell: ParentCell,forRowAt indexPath: IndexPath) {
        cell.presentationTheme = presentationTheme
        guard indexPath.section < charts.count else { return }
        let chart = charts[indexPath.section]
        let selectedCharts = chart.enumerated().compactMap { displayedCharts[indexPath.section].contains($0) ? $1 : nil }
        let visibleSegment = visibleSegments[indexPath.section]
        switch indexPath.row {
        case 0:
            let cell = cell as! ChartTableViewCell
            
            cell.chartView.chartData = selectedCharts
            cell.chartView.visibleSegment = visibleSegment
            cell.chartView.selectedDate = selectedDates[indexPath.section]
            cell.chartView.selectedDateChangedHandler = { [weak self] (selectedDate) in
                self?.selectedDates[indexPath.section] = selectedDate
            }
            return
            
        case 1:
            let cell = cell as! SliderTableViewCell
            
            cell.sliderView.minSelectedValue = CGFloat(visibleSegment.start)
            cell.sliderView.maxSelectedValue = CGFloat(visibleSegment.end)
            cell.sliderView.backgroundView.image = ChartDataSet.chartImage(selectedCharts,
                                                                           size: cell.sliderView.backgroundView.frame.size,
                                                                           lineWidth: cell.sliderView.backgroundView.frame.size.height/60)
            cell.valueChangedHandler = { [weak self] in
                let segment = Segment(start: TimeInterval(cell.sliderView!.minSelectedValue),
                                      end: TimeInterval(cell.sliderView!.maxSelectedValue))
                self?.visibleSegments[indexPath.section] = segment
                let chartCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: indexPath.section)) as? ChartTableViewCell
                chartCell?.chartView.visibleSegment = segment
            }
            return
            
        default:
            let cell = cell as! SelectionTableViewCell
            
            let dataSet = chart[indexPath.row - 2]
            cell.titleLabel.text = dataSet.name
            cell.colorMarkView.backgroundColor = dataSet.color
            cell.accessoryType = displayedCharts[indexPath.section].contains(indexPath.row - 2) ? .checkmark : .none
            cell.separatorViewOffsetConstraint.isActive = indexPath.row - 2 != chart.count - 1
            return
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
            return 44
        }
        return 46
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < charts.count else {
            presentationTheme = presentationTheme.isDark ? PresentationTheme.dayTheme : PresentationTheme.nightTheme
            UserDefaults.standard.set(presentationTheme.isDark, forKey: StatisticsViewController.themeUDKey)
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
            
            for indexPath in [
                IndexPath(row: 0, section: indexPath.section),
                IndexPath(row: 1, section: indexPath.section),
                indexPath
                ]
            {
                if let cell = tableView.cellForRow(at: indexPath) as? ParentCell {
                    configure(cell: cell, forRowAt: indexPath)
                }
            }
        }
    }
}
