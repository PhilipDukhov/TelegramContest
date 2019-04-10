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
    @IBOutlet weak var switchThemeButton: UIButton!
    
    var charts = [[ChartDataSet]]()
    var displayedChartInfos = [[SelectableInfo]]()
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
        
        let cacheFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cache")
        var data: Data?
        if let path = Bundle.main.path(forResource: "cache", ofType: nil) {
            data = try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        if data == nil {
            data = try? Data(contentsOf: cacheFilePath)
        }
        if let data = data,
            let charts = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [[ChartDataSet]]
        {
            self.charts = charts
        }
        else if let contestDirPath = Bundle.main.path(forResource: "contest 2", ofType: nil) {
            charts = ChartDataSet.parse(rootDir: URL(fileURLWithPath: contestDirPath))!
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: charts, requiringSecureCoding: false) {
                try? data.write(to: cacheFilePath)
            }
        }
//        charts = [charts[0]]
        
        displayedChartInfos = charts.map { $0.map { SelectableInfo(text: $0.name, color: $0.color, selected: true) } }
        visibleSegments = Array(repeating: Segment(start: 0, end: 1), count: charts.count)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return presentationTheme?.statusBarStyle ?? super.preferredStatusBarStyle
    }
    
    func presentationThemeUpdated() {
        tableView.backgroundColor = presentationTheme.tableViewBackgroundColor
        tableView.visibleCells.forEach { ($0 as? ParentCell)?.presentationTheme = presentationTheme }
        navigationBarView.backgroundColor = presentationTheme.cellBackgroundColor
        navigationBarTitleLabel.textColor =  presentationTheme.selectionTitleTextColor
        navigationBarSeparatorView.backgroundColor = presentationTheme.navigationBarSeparatorColor
        setNeedsStatusBarAppearanceUpdate()
        switchThemeButton.setTitle(presentationTheme.switchThemeText, for: .normal)
        switchThemeButton.setTitleColor(presentationTheme.switchThemeTextColor, for: .normal)
    }
    
    @IBAction func switchThemeButtonHandler(_ sender: Any) {
        presentationTheme = presentationTheme.isDark ? PresentationTheme.dayTheme : PresentationTheme.nightTheme
    }
}

extension StatisticsViewController: UITableViewDataSource {    
    func numberOfSections(in tableView: UITableView) -> Int {
        return charts.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return charts[section].count > 1 ? 3 : 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ParentCell
        defer {
            configure(cell: cell, forRowAt: indexPath)
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
    
    private func configure(cell: ParentCell, forRowAt indexPath: IndexPath) {
        cell.presentationTheme = presentationTheme
        guard indexPath.section < charts.count else { return }
        let chart = charts[indexPath.section]
        
        let displayedInfos = displayedChartInfos[indexPath.section]
        let selectedCharts = chart.enumerated().compactMap { displayedInfos[$0].selected ? $1 : nil }
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
            cell.selectableInfos = displayedChartInfos[indexPath.section]
            cell.selectionChangedHandler = { [weak self] index in
                guard let strongSelf = self else { return }
                if !strongSelf.displayedChartInfos[indexPath.section][index].selected ||
                    strongSelf.displayedChartInfos[indexPath.section].enumerated().first(where: { $0.0 != index && $0.1.selected }) != nil
                {
                    strongSelf.displayedChartInfos[indexPath.section][index].selected = !strongSelf.displayedChartInfos[indexPath.section][index].selected
                }
                else {
                    let alertVC = UIAlertController(title: "At least one chart should be selected",
                                                    message: nil,
                                                    preferredStyle: .alert)
                    alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    strongSelf.present(alertVC, animated: true, completion: nil)
                    return
                }
                cell.selectableInfos = strongSelf.displayedChartInfos[indexPath.section]
                for indexPath in [
                    IndexPath(row: 0, section: indexPath.section),
                    IndexPath(row: 1, section: indexPath.section)
                    ]
                {
                    if let cell = strongSelf.tableView.cellForRow(at: indexPath) as? ParentCell {
                        strongSelf.configure(cell: cell, forRowAt: indexPath)
                    }
                }

            }
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
            return 20 + SelectionTableViewCell.height(for: displayedChartInfos[indexPath.section],
                                                      maxWidth: view.bounds.width - view.layoutMargins.left - view.layoutMargins.right)
        }
        return 46
    }
}
